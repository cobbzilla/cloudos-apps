require 'securerandom'
require 'htauth'

class Chef::Recipe::Apache

  def self.reload(chef, reason = nil)
    reason = reason.to_s.empty? ? '' : "(#{reason})"
    chef.bash "restart Apache #{reason}" do
      user 'root'
      code <<-EOH
if [[ "$(service apache2 status)" =~ "not running" ]] ; then
  service apache2 start
else
  service apache2 reload
fi

if [ -f /etc/init/php5-fpm.conf ] ; then
  service apache2 restart
  if [[ "$(service php5-fpm status)" =~ "not running" ]] ; then
    service php5-fpm start
  else
    service php5-fpm restart
  fi
fi
      EOH
    end
  end

  def self.get_server_name (preset, mode, hostname, app_name)
    return preset unless preset.to_s.empty?
    (mode == :proxy_root || mode == :vhost_root) ? hostname : "#{app_name}-#{hostname}"
  end

  def self.new_module (chef, module_name)
    chef.cookbook_file "/usr/lib/apache2/modules/mod_#{module_name}.so" do
      owner 'root'
      group 'root'
      mode '0644'
      action :create
    end
    chef.template "/etc/apache2/mods-enabled/#{module_name}.load" do
      source 'module.load.erb'
      cookbook 'apache'
      owner 'root'
      group 'root'
      mode '0644'
      variables ({ :module_name => module_name })
      action :create
    end
  end

  def self.enable_module (chef, module_name)
    chef.bash "enable Apache module: #{module_name}" do
      user 'root'
      cwd '/tmp'
      code <<-EOH

if [[ #{module_name} =~ mpm_.+ ]] ; then
  # disable any existing mpm modules (there should be only 1, but just in case...)
  for mpm in $(find /etc/apache2/mods-enabled -name "mpm_*.load" | xargs basename | awk -F '.' '{print $1}') ; do
    a2dismod ${mpm}
  done

elif [ #{module_name} == "php5-fpm" ] ; then
  # disable existing php module if enabled
  if [ -e /etc/apache2/mods-enabled/php5.load ] ; then
    a2dismod php5
  fi
fi

a2enmod #{module_name}
      EOH
      not_if { File.exist? "/etc/apache2/mods-enabled/#{module_name}.load" }
    end
  end

  def self.disable_module (chef, module_name)
    chef.bash "disable Apache module: #{module_name}" do
      user 'root'
      cwd '/tmp'
      code <<-EOH
a2dismod #{module_name}
      EOH
      only_if { File.exist? "/etc/apache2/mods-enabled/#{module_name}.load" }
    end
  end

  def self.define_app (chef, app_name, config = nil)

    scope = {
        :hostname => %x(hostname).strip,
        :ip_address => chef.node['ipaddress'],
        :app_name => app_name,
        :config => config
    }

    [ "/etc/apache2/apps/#{app_name}", "/etc/apache2/mixins/#{app_name}" ].each do |dir|
      chef.directory dir do
        group 'www-data'
        mode '0755'
        action :create
        recursive true
      end
    end

    # normalize mount and local_mount -- ensure it begins with a slash and does not end with a slash (unless it is just /)
    config[:mount] = normalize_mount(config[:mount])
    config[:local_mount] = normalize_mount(config[:local_mount])

    # Ensure trailing slash of local_mount matches mount
    if config[:mount].end_with? '/'
      config[:local_mount] += '/' unless config[:local_mount].end_with? '/'
    else
      config[:local_mount] = config[:local_mount].chomp('/') if config[:local_mount].end_with? '/'
    end

    if defined? config[:mode]
      m = config[:mode]
        if m == :service || m == :proxy_service
          self.define_service(chef, scope)
        elsif m == :vhost || m == :vhost_root || m == :proxy || m == :proxy_root
          self.define_vhost(chef, scope)
        else
          raise "Unknown mode: #{config[:mode]}"
      end

      # any mode may have htaccess files
      if config[:htaccess]
        config[:htaccess].each do |htaccess|
          dest = "#{htaccess.sub('@doc_root', config[:doc_root])}/.htaccess"
          src = "apache_htaccess_#{htaccess.sub('@doc_root', 'doc_root').sub('/', '_')}.conf.erb"
          self.subst_template(chef, src, dest, scope)
        end
      end

      # any mode may have mixins
      if config[:mixins]
        config[:mixins].each do |mixin|
          dest = "/etc/apache2/mixins/#{File.basename mixin}"
          src = "#{mixin}.erb"
          self.subst_template(chef, src, dest, scope)
        end
      end

    else
      self.subst_template(chef, "#{app_name}.conf.erb", "/etc/apache2/sites-available/#{app_name}.conf", scope, 'apache')
      self.enable_site(chef, app_name)
    end
  end

  def self.uninstall_app (chef, app_name, config = nil)
    if defined? config[:mode]
      m = config[:mode]
      if m == :service || m == :proxy_service
        self.disable_service chef, scope

      elsif m == :vhost || m == :vhost_root || m == :proxy || m == :proxy_root
        self.disable_site chef, app_name

      else
        raise "Unknown mode: #{config[:mode]}"
      end

    else
      self.disable_site chef, app_name
    end

    apps_dir="/etc/apache2/apps/#{app_name}"
    if File.exist? apps_dir
      chef.bash "removing apache apps dir: #{apps_dir}" do
        user 'root'
        cwd '/tmp'
        code <<-EOH
rm -rf #{apps_dir}
        EOH
      end
    end
  end

  def self.normalize_mount(mount)
    # ensure it begins with a slash and does not end with a slash (unless it is the single-char '/')
    mount ||= '/'
    mount = "/#{mount}" unless mount.start_with? '/'
    (mount.end_with? '/' && mount != '/') ? mount[0 .. -2] : mount
  end

  def self.dir_base (dir)
    dir.sub('@doc_root', 'doc_root').gsub('/', '_')
  end

  def self.dir_config_path (app_name, base)
    "/etc/apache2/apps/#{app_name}/dir_#{base}.conf"
  end

  def self.loc_base (loc)
    if loc.to_s == '' || loc == '/'
      return 'location_root'
    end
    if loc.start_with? '/'
      return "location_root_#{loc[1..loc.length].gsub('/', '_')}"
    else
      return "location_#{loc.gsub('/', '_')}"
    end
  end

  def self.loc_config_path (app_name, base)
    "/etc/apache2/apps/#{app_name}/#{base}.conf"
  end

  def self.define_vhost(chef, scope)

    app_name = scope[:app_name]
    config = scope[:config]

    write_vhost_template(app_name, chef, config, scope)

    subst_template(chef, 'app_vhost.conf.erb', "/etc/apache2/sites-available/#{app_name}.conf", scope, 'apache')
    chef.directory config[:doc_root] do
      group 'www-data'
      mode '0755'
      recursive true
      action :create
    end
    chef.cookbook_file "#{config[:doc_root]}/robots.txt" do
      group 'www-data'
      mode '0644'
      action :create
      cookbook 'apache'
    end
    enable_site(chef, app_name)

    define_dir_configs(app_name, chef, config, scope) if config[:dir]
    define_location_configs(app_name, chef, config, scope) if config[:location]
  end

  def self.define_location_configs(app_name, chef, config, scope)
    config[:location].each do |loc|
      file_base = loc_base(loc)
      dest = loc_config_path app_name, file_base
      src = "apache_#{file_base}.conf.erb"
      self.subst_template(chef, src, dest, scope)
    end
  end

  def self.define_dir_configs(app_name, chef, config, scope)
    config[:dir].each do |dir|
      file_base = dir_base(dir)
      dest = dir_config_path app_name, file_base
      src = "apache_dir_#{file_base}.conf.erb"
      self.subst_template(chef, src, dest, scope)
    end
  end

  def self.define_service(chef, scope)

    app_name = scope[:app_name]
    config = scope[:config]

    if config[:mode] == :proxy_service && config[:mount] == '/'
      raise "define_service: refusing to proxy root of default domain: #{app_name}"
    end

    write_vhost_template(app_name, chef, config, scope)

    self.subst_template(chef, 'app_service.conf.erb', "/etc/apache2/https-services-available/#{app_name}", scope, 'apache')
    self.subst_template(chef, 'app_service_rewrite.conf.erb', "/etc/apache2/rewrite-rules-available/#{app_name}", scope, 'apache')

    define_dir_configs(app_name, chef, config, scope) if config[:dir]
    define_location_configs(app_name, chef, config, scope) if config[:location]

    self.enable_service(chef, app_name)
  end

  def self.write_vhost_template(app_name, chef, config, scope)
    if config[:vhost]
      dest = "/etc/apache2/apps/#{app_name}/vhost.conf"
      src = 'apache_vhost.conf.erb'
      self.subst_template(chef, src, dest, scope)
    end
  end

  def self.enable_site(chef, site_name)
    chef.bash "enable Apache site: #{site_name}" do
      user 'root'
      cwd '/tmp'
      code <<-EOH
a2ensite #{site_name}
      EOH
    end
  end

  def self.disable_site (chef, site_name)
    site_name = '000-default' if site_name == 'default'
    chef.bash "disable Apache site: #{site_name}" do
      user 'root'
      cwd '/tmp'
      code <<-EOH
# always return true because site may already be disabled
a2dissite #{site_name} || true
      EOH
    end
  end

  def self.enable_service(chef, service_name)
    chef.bash "enable Apache service: #{service_name}" do
      user 'root'
      cwd '/tmp'
      code <<-EOH
ln -sf /etc/apache2/https-services-available/#{service_name} /etc/apache2/https-services-enabled/#{service_name}
ln -sf /etc/apache2/rewrite-rules-available/#{service_name} /etc/apache2/rewrite-rules-enabled/#{service_name}
      EOH
    end
  end

  def self.disable_service(chef, service_name)
    chef.bash "disable Apache service: #{service_name}" do
      user 'root'
      cwd '/tmp'
      code <<-EOH
rm -f /etc/apache2/https-services-enabled/#{service_name}
rm -f /etc/apache2/rewrite-rules-enabled/#{service_name}
      EOH
    end
  end

  def self.set_php_ini(chef, key, value, overwrite = false)
    value_hash = Digest::SHA256.hexdigest(value)
    ini_file = "50-#{key}-#{value_hash}.ini"
    php_ini = "/etc/php5/mods-available/#{ini_file}"

    chef.bash "setting #{key}=#{value} in #{php_ini} (overwrite=#{overwrite})" do
      user 'root'
      code <<-EOH
if [ "#{overwrite}" = "true" ] ; then
  rm -f #{php_ini}
fi
echo "#{key}=#{value}" > #{php_ini}
if [ -d /etc/php5/apache2/conf.d ] ; then
  cd /etc/php5/apache2/conf.d && ln -sf ../../mods-available/#{ini_file}
fi
if [ -d /etc/php5/fpm/conf.d ] ; then
  cd /etc/php5/fpm/conf.d && ln -sf ../../mods-available/#{ini_file}
fi
      EOH
    end
  end

  def self.subst_template(chef, source, destination, scope = {}, cb = nil)
    chef.directory File.dirname(destination) do
      group 'www-data'
      mode '0755'
      recursive false
      action :create
    end

    begin
      scope['cloudos_port'] = chef.data_bag_item('cloudos', 'ports')['primary']
    rescue
      puts 'error reading cloudos_port'
    end

    chef.template destination do
      source source unless source.start_with? '/'
      local source if source.start_with? '/'
      cookbook cb
      group 'www-data'
      mode '0644'
      variables (scope)
      action :create
    end
  end

  def self.add_digest_user(digest_passwd_file, realm, user, password)
    unless File.exist?(digest_passwd_file)
      File.open(digest_passwd_file, 'w') {}
    end
    HTAuth::DigestFile.open(digest_passwd_file) do |df|
      df.add_or_update(user, realm, password)
    end
  end

end
