--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: account; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE account (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    name character varying(100) NOT NULL,
    admin boolean NOT NULL,
    auth_id character varying(30),
    email character varying(255) NOT NULL,
    email_verification_code character varying(100),
    email_verification_code_created_at bigint,
    email_verified boolean NOT NULL,
    first_name character varying(25) NOT NULL,
    hashed_password character varying(200) NOT NULL,
    reset_token character varying(30),
    reset_token_ctime bigint,
    last_login bigint,
    last_name character varying(25) NOT NULL,
    locale character varying(40),
    mobile_phone character varying(30),
    mobile_phone_country_code integer,
    suspended boolean NOT NULL,
    two_factor boolean NOT NULL,
    primary_group character varying(100),
    storage_quota character varying(10)
);


ALTER TABLE public.account OWNER TO cloudos;

--
-- Name: account_device; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE account_device (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    account character varying(255),
    auth_time bigint,
    device_id character varying(255),
    device_name character varying(255)
);


ALTER TABLE public.account_device OWNER TO cloudos;

--
-- Name: account_group; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE account_group (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(200),
    storage_quota character varying(10),
    mirror character varying(100)
);


ALTER TABLE public.account_group OWNER TO cloudos;

--
-- Name: account_group_member; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE account_group_member (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    group_name character varying(100) NOT NULL,
    group_uuid character varying(100) NOT NULL,
    member_name character varying(100) NOT NULL,
    member_uuid character varying(100) NOT NULL,
    type character varying(255)
);


ALTER TABLE public.account_group_member OWNER TO cloudos;

--
-- Name: cloud_os_event; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE cloud_os_event (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    exception character varying(32000),
    message_key character varying(1000) NOT NULL,
    success boolean NOT NULL,
    task_id character varying(100) NOT NULL,
    cloud_os_uuid character varying(100) NOT NULL
);


ALTER TABLE public.cloud_os_event OWNER TO cloudos;

--
-- Name: email_domain; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE email_domain (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    name character varying(255) NOT NULL
);


ALTER TABLE public.email_domain OWNER TO cloudos;

--
-- Name: ssl_certificate; Type: TABLE; Schema: public; Owner: cloudos; Tablespace: 
--

CREATE TABLE ssl_certificate (
    uuid character varying(100) NOT NULL,
    ctime bigint NOT NULL,
    name character varying(100) NOT NULL,
    common_name character varying(255),
    description character varying(255),
    key_md5 character varying(255),
    key_sha character varying(255),
    pem_md5 character varying(255),
    pem_sha character varying(255)
);


ALTER TABLE public.ssl_certificate OWNER TO cloudos;

--
-- Data for Name: account; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY account (uuid, ctime, name, admin, auth_id, email, email_verification_code, email_verification_code_created_at, email_verified, first_name, hashed_password, reset_token, reset_token_ctime, last_login, last_name, locale, mobile_phone, mobile_phone_country_code, suspended, two_factor, primary_group, storage_quota) FROM stdin;
\.


--
-- Data for Name: account_device; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY account_device (uuid, ctime, account, auth_time, device_id, device_name) FROM stdin;
\.


--
-- Data for Name: account_group; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY account_group (uuid, ctime, name, description, storage_quota, mirror) FROM stdin;
\.


--
-- Data for Name: account_group_member; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY account_group_member (uuid, ctime, group_name, group_uuid, member_name, member_uuid, type) FROM stdin;
\.


--
-- Data for Name: cloud_os_event; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY cloud_os_event (uuid, ctime, exception, message_key, success, task_id, cloud_os_uuid) FROM stdin;
\.


--
-- Data for Name: email_domain; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY email_domain (uuid, ctime, name) FROM stdin;
\.


--
-- Data for Name: ssl_certificate; Type: TABLE DATA; Schema: public; Owner: cloudos
--

COPY ssl_certificate (uuid, ctime, name, common_name, description, key_md5, key_sha, pem_md5, pem_sha) FROM stdin;
e1f3aa5b-f6f8-4afe-a86e-edaa4ce174cf	1440623663396	ssl-https	*.cloudstead.io	cloudstead.io wildcard certificate	23a5bcd716f54cc819a7367e64fe70e9	1844d332ccb478a82eb038e947988b1b1e5b7882ddda85456efbc89bca327e97	e367ebcdec3792a33c0005e8b8098040	761f5e4128089695d51600c36e6b96438828e0ee7c76d7a15da2c13516832417
\.


--
-- Name: account_device_account_device_id_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account_device
    ADD CONSTRAINT account_device_account_device_id_key UNIQUE (account, device_id);


--
-- Name: account_device_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account_device
    ADD CONSTRAINT account_device_pkey PRIMARY KEY (uuid);


--
-- Name: account_email_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account
    ADD CONSTRAINT account_email_key UNIQUE (email);


--
-- Name: account_group_member_group_name_member_name_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account_group_member
    ADD CONSTRAINT account_group_member_group_name_member_name_key UNIQUE (group_name, member_name);


--
-- Name: account_group_member_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account_group_member
    ADD CONSTRAINT account_group_member_pkey PRIMARY KEY (uuid);


--
-- Name: account_group_name_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account_group
    ADD CONSTRAINT account_group_name_key UNIQUE (name);


--
-- Name: account_group_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account_group
    ADD CONSTRAINT account_group_pkey PRIMARY KEY (uuid);


--
-- Name: account_name_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account
    ADD CONSTRAINT account_name_key UNIQUE (name);


--
-- Name: account_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY account
    ADD CONSTRAINT account_pkey PRIMARY KEY (uuid);


--
-- Name: cloud_os_event_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY cloud_os_event
    ADD CONSTRAINT cloud_os_event_pkey PRIMARY KEY (uuid);


--
-- Name: email_domain_name_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY email_domain
    ADD CONSTRAINT email_domain_name_key UNIQUE (name);


--
-- Name: email_domain_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY email_domain
    ADD CONSTRAINT email_domain_pkey PRIMARY KEY (uuid);


--
-- Name: ssl_certificate_name_key; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY ssl_certificate
    ADD CONSTRAINT ssl_certificate_name_key UNIQUE (name);


--
-- Name: ssl_certificate_pkey; Type: CONSTRAINT; Schema: public; Owner: cloudos; Tablespace: 
--

ALTER TABLE ONLY ssl_certificate
    ADD CONSTRAINT ssl_certificate_pkey PRIMARY KEY (uuid);


--
-- Name: public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM postgres;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--

