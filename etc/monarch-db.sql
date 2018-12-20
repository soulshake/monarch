--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'LATIN1';
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
-- Name: access_list; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE access_list (
    object character varying(50) NOT NULL,
    type character varying(50) NOT NULL,
    usergroup_id integer DEFAULT 0 NOT NULL,
    access_values character varying(20)
);


ALTER TABLE public.access_list OWNER TO monarch;

--
-- Name: commands; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE commands (
    command_id integer NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(50),
    data text,
    comment text
);


ALTER TABLE public.commands OWNER TO monarch;

--
-- Name: commands_command_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE commands_command_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.commands_command_id_seq OWNER TO monarch;

--
-- Name: commands_command_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE commands_command_id_seq OWNED BY commands.command_id;


--
-- Name: contact_command; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_command (
    contacttemplate_id integer DEFAULT 0 NOT NULL,
    type character varying(50) NOT NULL,
    command_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_command OWNER TO monarch;

--
-- Name: contact_command_overrides; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_command_overrides (
    contact_id integer DEFAULT 0 NOT NULL,
    type character varying(50) NOT NULL,
    command_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_command_overrides OWNER TO monarch;

--
-- Name: contact_group; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_group (
    contact_id integer DEFAULT 0 NOT NULL,
    group_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_group OWNER TO monarch;

--
-- Name: contact_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_host (
    contact_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_host OWNER TO monarch;

--
-- Name: contact_host_profile; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_host_profile (
    contact_id integer DEFAULT 0 NOT NULL,
    hostprofile_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_host_profile OWNER TO monarch;

--
-- Name: contact_host_template; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_host_template (
    contact_id integer DEFAULT 0 NOT NULL,
    hosttemplate_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_host_template OWNER TO monarch;

--
-- Name: contact_hostgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_hostgroup (
    contact_id integer DEFAULT 0 NOT NULL,
    hostgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_hostgroup OWNER TO monarch;

--
-- Name: contact_overrides; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_overrides (
    contact_id integer DEFAULT 0 NOT NULL,
    host_notification_period integer,
    service_notification_period integer,
    data text
);


ALTER TABLE public.contact_overrides OWNER TO monarch;

--
-- Name: contact_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_service (
    contact_id integer DEFAULT 0 NOT NULL,
    service_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_service OWNER TO monarch;

--
-- Name: contact_service_name; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_service_name (
    contact_id integer DEFAULT 0 NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_service_name OWNER TO monarch;

--
-- Name: contact_service_template; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_service_template (
    contact_id integer DEFAULT 0 NOT NULL,
    servicetemplate_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contact_service_template OWNER TO monarch;

--
-- Name: contact_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contact_templates (
    contacttemplate_id integer NOT NULL,
    name character varying(255) NOT NULL,
    host_notification_period integer,
    service_notification_period integer,
    data text,
    comment text
);


ALTER TABLE public.contact_templates OWNER TO monarch;

--
-- Name: contact_templates_contacttemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE contact_templates_contacttemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contact_templates_contacttemplate_id_seq OWNER TO monarch;

--
-- Name: contact_templates_contacttemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE contact_templates_contacttemplate_id_seq OWNED BY contact_templates.contacttemplate_id;


--
-- Name: contactgroup_contact; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_contact (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    contact_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_contact OWNER TO monarch;

--
-- Name: contactgroup_group; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_group (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    group_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_group OWNER TO monarch;

--
-- Name: contactgroup_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_host (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_host OWNER TO monarch;

--
-- Name: contactgroup_host_profile; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_host_profile (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    hostprofile_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_host_profile OWNER TO monarch;

--
-- Name: contactgroup_host_template; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_host_template (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    hosttemplate_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_host_template OWNER TO monarch;

--
-- Name: contactgroup_hostgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_hostgroup (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    hostgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_hostgroup OWNER TO monarch;

--
-- Name: contactgroup_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_service (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    service_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_service OWNER TO monarch;

--
-- Name: contactgroup_service_name; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_service_name (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_service_name OWNER TO monarch;

--
-- Name: contactgroup_service_template; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroup_service_template (
    contactgroup_id integer DEFAULT 0 NOT NULL,
    servicetemplate_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.contactgroup_service_template OWNER TO monarch;

--
-- Name: contactgroups; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contactgroups (
    contactgroup_id integer NOT NULL,
    name character varying(255) NOT NULL,
    alias character varying(255) NOT NULL,
    comment text
);


ALTER TABLE public.contactgroups OWNER TO monarch;

--
-- Name: contactgroups_contactgroup_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE contactgroups_contactgroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contactgroups_contactgroup_id_seq OWNER TO monarch;

--
-- Name: contactgroups_contactgroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE contactgroups_contactgroup_id_seq OWNED BY contactgroups.contactgroup_id;


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE contacts (
    contact_id integer NOT NULL,
    name character varying(255) NOT NULL,
    alias character varying(255) NOT NULL,
    email text,
    pager text,
    contacttemplate_id integer,
    status smallint,
    comment text
);


ALTER TABLE public.contacts OWNER TO monarch;

--
-- Name: contacts_contact_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE contacts_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.contacts_contact_id_seq OWNER TO monarch;

--
-- Name: contacts_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE contacts_contact_id_seq OWNED BY contacts.contact_id;


--
-- Name: datatype; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE datatype (
    datatype_id integer NOT NULL,
    type character varying(100) NOT NULL,
    location character varying(255) NOT NULL
);


ALTER TABLE public.datatype OWNER TO monarch;

--
-- Name: datatype_datatype_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE datatype_datatype_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.datatype_datatype_id_seq OWNER TO monarch;

--
-- Name: datatype_datatype_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE datatype_datatype_id_seq OWNED BY datatype.datatype_id;


--
-- Name: discover_filter; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE discover_filter (
    filter_id integer NOT NULL,
    name character varying(255),
    type character varying(50),
    filter text
);


ALTER TABLE public.discover_filter OWNER TO monarch;

--
-- Name: discover_filter_filter_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE discover_filter_filter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.discover_filter_filter_id_seq OWNER TO monarch;

--
-- Name: discover_filter_filter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE discover_filter_filter_id_seq OWNED BY discover_filter.filter_id;


--
-- Name: discover_group; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE discover_group (
    group_id integer NOT NULL,
    name character varying(255),
    description text,
    config text,
    schema_id integer
);


ALTER TABLE public.discover_group OWNER TO monarch;

--
-- Name: discover_group_filter; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE discover_group_filter (
    group_id integer DEFAULT 0 NOT NULL,
    filter_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.discover_group_filter OWNER TO monarch;

--
-- Name: discover_group_group_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE discover_group_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.discover_group_group_id_seq OWNER TO monarch;

--
-- Name: discover_group_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE discover_group_group_id_seq OWNED BY discover_group.group_id;


--
-- Name: discover_group_method; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE discover_group_method (
    group_id integer DEFAULT 0 NOT NULL,
    method_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.discover_group_method OWNER TO monarch;

--
-- Name: discover_method; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE discover_method (
    method_id integer NOT NULL,
    name character varying(255),
    description text,
    config text,
    type character varying(50)
);


ALTER TABLE public.discover_method OWNER TO monarch;

--
-- Name: discover_method_filter; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE discover_method_filter (
    method_id integer DEFAULT 0 NOT NULL,
    filter_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.discover_method_filter OWNER TO monarch;

--
-- Name: discover_method_method_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE discover_method_method_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.discover_method_method_id_seq OWNER TO monarch;

--
-- Name: discover_method_method_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE discover_method_method_id_seq OWNED BY discover_method.method_id;


--
-- Name: escalation_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE escalation_templates (
    template_id integer NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(50) NOT NULL,
    data text,
    comment text,
    escalation_period integer
);


ALTER TABLE public.escalation_templates OWNER TO monarch;

--
-- Name: escalation_templates_template_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE escalation_templates_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.escalation_templates_template_id_seq OWNER TO monarch;

--
-- Name: escalation_templates_template_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE escalation_templates_template_id_seq OWNED BY escalation_templates.template_id;


--
-- Name: escalation_tree_template; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE escalation_tree_template (
    tree_id integer DEFAULT 0 NOT NULL,
    template_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.escalation_tree_template OWNER TO monarch;

--
-- Name: escalation_trees; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE escalation_trees (
    tree_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(100),
    type character varying(50) NOT NULL
);


ALTER TABLE public.escalation_trees OWNER TO monarch;

--
-- Name: escalation_trees_tree_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE escalation_trees_tree_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.escalation_trees_tree_id_seq OWNER TO monarch;

--
-- Name: escalation_trees_tree_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE escalation_trees_tree_id_seq OWNED BY escalation_trees.tree_id;


--
-- Name: extended_host_info_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE extended_host_info_templates (
    hostextinfo_id integer NOT NULL,
    name character varying(255) NOT NULL,
    data text,
    script character varying(255),
    comment text
);


ALTER TABLE public.extended_host_info_templates OWNER TO monarch;

--
-- Name: extended_host_info_templates_hostextinfo_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE extended_host_info_templates_hostextinfo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.extended_host_info_templates_hostextinfo_id_seq OWNER TO monarch;

--
-- Name: extended_host_info_templates_hostextinfo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE extended_host_info_templates_hostextinfo_id_seq OWNED BY extended_host_info_templates.hostextinfo_id;


--
-- Name: extended_info_coords; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE extended_info_coords (
    host_id integer DEFAULT 0 NOT NULL,
    data text
);


ALTER TABLE public.extended_info_coords OWNER TO monarch;

--
-- Name: extended_service_info_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE extended_service_info_templates (
    serviceextinfo_id integer NOT NULL,
    name character varying(255) NOT NULL,
    data text,
    script character varying(255),
    comment text
);


ALTER TABLE public.extended_service_info_templates OWNER TO monarch;

--
-- Name: extended_service_info_templates_serviceextinfo_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE extended_service_info_templates_serviceextinfo_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.extended_service_info_templates_serviceextinfo_id_seq OWNER TO monarch;

--
-- Name: extended_service_info_templates_serviceextinfo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE extended_service_info_templates_serviceextinfo_id_seq OWNED BY extended_service_info_templates.serviceextinfo_id;


--
-- Name: external_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE external_host (
    external_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL,
    data text,
    modified smallint
);


ALTER TABLE public.external_host OWNER TO monarch;

--
-- Name: external_host_profile; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE external_host_profile (
    external_id integer DEFAULT 0 NOT NULL,
    hostprofile_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.external_host_profile OWNER TO monarch;

--
-- Name: external_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE external_service (
    external_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL,
    service_id integer DEFAULT 0 NOT NULL,
    data text,
    modified smallint
);


ALTER TABLE public.external_service OWNER TO monarch;

--
-- Name: external_service_names; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE external_service_names (
    external_id integer DEFAULT 0 NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.external_service_names OWNER TO monarch;

--
-- Name: externals; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE externals (
    external_id integer NOT NULL,
    name character varying(255),
    description character varying(50),
    type character varying(20) NOT NULL,
    display text,
    handler text
);


ALTER TABLE public.externals OWNER TO monarch;

--
-- Name: externals_external_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE externals_external_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.externals_external_id_seq OWNER TO monarch;

--
-- Name: externals_external_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE externals_external_id_seq OWNED BY externals.external_id;


--
-- Name: host_dependencies; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE host_dependencies (
    host_id integer DEFAULT 0 NOT NULL,
    parent_id integer DEFAULT 0 NOT NULL,
    data text,
    comment text
);


ALTER TABLE public.host_dependencies OWNER TO monarch;

--
-- Name: host_overrides; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE host_overrides (
    host_id integer DEFAULT 0 NOT NULL,
    check_period integer,
    notification_period integer,
    check_command integer,
    event_handler integer,
    data text
);


ALTER TABLE public.host_overrides OWNER TO monarch;

--
-- Name: host_parent; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE host_parent (
    host_id integer DEFAULT 0 NOT NULL,
    parent_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.host_parent OWNER TO monarch;

--
-- Name: host_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE host_service (
    host_service_id integer NOT NULL,
    host character varying(255) NOT NULL,
    service character varying(255) NOT NULL,
    label character varying(100) NOT NULL,
    dataname character varying(100) NOT NULL,
    datatype_id integer DEFAULT 0
);


ALTER TABLE public.host_service OWNER TO monarch;

--
-- Name: host_service_host_service_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE host_service_host_service_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.host_service_host_service_id_seq OWNER TO monarch;

--
-- Name: host_service_host_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE host_service_host_service_id_seq OWNED BY host_service.host_service_id;


--
-- Name: host_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE host_templates (
    hosttemplate_id integer NOT NULL,
    name character varying(255) NOT NULL,
    check_period integer,
    notification_period integer,
    check_command integer,
    event_handler integer,
    data text,
    comment text
);


ALTER TABLE public.host_templates OWNER TO monarch;

--
-- Name: host_templates_hosttemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE host_templates_hosttemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.host_templates_hosttemplate_id_seq OWNER TO monarch;

--
-- Name: host_templates_hosttemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE host_templates_hosttemplate_id_seq OWNED BY host_templates.hosttemplate_id;


--
-- Name: hostgroup_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE hostgroup_host (
    hostgroup_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.hostgroup_host OWNER TO monarch;

--
-- Name: hostgroups; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE hostgroups (
    hostgroup_id integer NOT NULL,
    name character varying(255) NOT NULL,
    alias character varying(255) NOT NULL,
    hostprofile_id integer,
    host_escalation_id integer,
    service_escalation_id integer,
    status smallint,
    comment text,
    notes character varying(4096)
);


ALTER TABLE public.hostgroups OWNER TO monarch;

--
-- Name: hostgroups_hostgroup_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE hostgroups_hostgroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hostgroups_hostgroup_id_seq OWNER TO monarch;

--
-- Name: hostgroups_hostgroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE hostgroups_hostgroup_id_seq OWNED BY hostgroups.hostgroup_id;


--
-- Name: hostprofile_overrides; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE hostprofile_overrides (
    hostprofile_id integer DEFAULT 0 NOT NULL,
    check_period integer,
    notification_period integer,
    check_command integer,
    event_handler integer,
    data text
);


ALTER TABLE public.hostprofile_overrides OWNER TO monarch;

--
-- Name: hosts; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE hosts (
    host_id integer NOT NULL,
    name character varying(255),
    alias character varying(255) NOT NULL,
    address character varying(50) NOT NULL,
    os character varying(50),
    hosttemplate_id integer,
    hostextinfo_id integer,
    hostprofile_id integer,
    host_escalation_id integer,
    service_escalation_id integer,
    status smallint,
    comment text,
    notes character varying(4096)
);


ALTER TABLE public.hosts OWNER TO monarch;

--
-- Name: hosts_host_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE hosts_host_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hosts_host_id_seq OWNER TO monarch;

--
-- Name: hosts_host_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE hosts_host_id_seq OWNED BY hosts.host_id;


--
-- Name: import_column; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_column (
    column_id integer NOT NULL,
    schema_id integer,
    name character varying(255),
    "position" integer,
    delimiter character varying(50)
);


ALTER TABLE public.import_column OWNER TO monarch;

--
-- Name: import_column_column_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE import_column_column_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.import_column_column_id_seq OWNER TO monarch;

--
-- Name: import_column_column_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE import_column_column_id_seq OWNED BY import_column.column_id;


--
-- Name: import_hosts; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_hosts (
    import_hosts_id integer NOT NULL,
    name character varying(255),
    alias character varying(255),
    address character varying(50),
    hostprofile_id integer
);


ALTER TABLE public.import_hosts OWNER TO monarch;

--
-- Name: import_hosts_import_hosts_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE import_hosts_import_hosts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.import_hosts_import_hosts_id_seq OWNER TO monarch;

--
-- Name: import_hosts_import_hosts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE import_hosts_import_hosts_id_seq OWNED BY import_hosts.import_hosts_id;


--
-- Name: import_match; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match (
    match_id integer NOT NULL,
    column_id integer,
    name character varying(255),
    match_order integer,
    match_type character varying(255),
    match_string character varying(255),
    rule character varying(255),
    object character varying(255),
    hostprofile_id integer,
    servicename_id integer,
    arguments character varying(508)
);


ALTER TABLE public.import_match OWNER TO monarch;

--
-- Name: import_match_contactgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match_contactgroup (
    match_id integer DEFAULT 0 NOT NULL,
    contactgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.import_match_contactgroup OWNER TO monarch;

--
-- Name: import_match_group; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match_group (
    match_id integer DEFAULT 0 NOT NULL,
    group_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.import_match_group OWNER TO monarch;

--
-- Name: import_match_hostgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match_hostgroup (
    match_id integer DEFAULT 0 NOT NULL,
    hostgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.import_match_hostgroup OWNER TO monarch;

--
-- Name: import_match_match_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE import_match_match_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.import_match_match_id_seq OWNER TO monarch;

--
-- Name: import_match_match_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE import_match_match_id_seq OWNED BY import_match.match_id;


--
-- Name: import_match_parent; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match_parent (
    match_id integer DEFAULT 0 NOT NULL,
    parent_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.import_match_parent OWNER TO monarch;

--
-- Name: import_match_servicename; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match_servicename (
    match_id integer DEFAULT 0 NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.import_match_servicename OWNER TO monarch;

--
-- Name: import_match_serviceprofile; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_match_serviceprofile (
    match_id integer DEFAULT 0 NOT NULL,
    serviceprofile_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.import_match_serviceprofile OWNER TO monarch;

--
-- Name: import_schema; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_schema (
    schema_id integer NOT NULL,
    name character varying(255),
    delimiter character varying(50),
    description text,
    type character varying(255),
    sync_object character varying(50),
    smart_name smallint DEFAULT 0,
    hostprofile_id integer DEFAULT 0,
    data_source character varying(255)
);


ALTER TABLE public.import_schema OWNER TO monarch;

--
-- Name: import_schema_schema_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE import_schema_schema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.import_schema_schema_id_seq OWNER TO monarch;

--
-- Name: import_schema_schema_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE import_schema_schema_id_seq OWNED BY import_schema.schema_id;


--
-- Name: import_services; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE import_services (
    import_services_id integer NOT NULL,
    import_hosts_id integer,
    description character varying(255),
    check_command_id integer,
    command_line character varying(255),
    command_line_trans character varying(255),
    servicename_id integer,
    serviceprofile_id integer
);


ALTER TABLE public.import_services OWNER TO monarch;

--
-- Name: import_services_import_services_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE import_services_import_services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.import_services_import_services_id_seq OWNER TO monarch;

--
-- Name: import_services_import_services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE import_services_import_services_id_seq OWNED BY import_services.import_services_id;


--
-- Name: monarch_group_child; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_group_child (
    group_id integer DEFAULT 0 NOT NULL,
    child_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.monarch_group_child OWNER TO monarch;

--
-- Name: monarch_group_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_group_host (
    group_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.monarch_group_host OWNER TO monarch;

--
-- Name: monarch_group_hostgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_group_hostgroup (
    group_id integer DEFAULT 0 NOT NULL,
    hostgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.monarch_group_hostgroup OWNER TO monarch;

--
-- Name: monarch_group_macro; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_group_macro (
    group_id integer DEFAULT 0 NOT NULL,
    macro_id integer DEFAULT 0 NOT NULL,
    value character varying(255)
);


ALTER TABLE public.monarch_group_macro OWNER TO monarch;

--
-- Name: monarch_group_props; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_group_props (
    prop_id integer NOT NULL,
    group_id integer,
    name character varying(255),
    type character varying(20),
    value character varying(1020)
);


ALTER TABLE public.monarch_group_props OWNER TO monarch;

--
-- Name: monarch_group_props_prop_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE monarch_group_props_prop_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.monarch_group_props_prop_id_seq OWNER TO monarch;

--
-- Name: monarch_group_props_prop_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE monarch_group_props_prop_id_seq OWNED BY monarch_group_props.prop_id;


--
-- Name: monarch_groups; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_groups (
    group_id integer NOT NULL,
    name character varying(255),
    description character varying(255),
    location text,
    status smallint,
    data text
);


ALTER TABLE public.monarch_groups OWNER TO monarch;

--
-- Name: monarch_groups_group_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE monarch_groups_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.monarch_groups_group_id_seq OWNER TO monarch;

--
-- Name: monarch_groups_group_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE monarch_groups_group_id_seq OWNED BY monarch_groups.group_id;


--
-- Name: monarch_macros; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE monarch_macros (
    macro_id integer NOT NULL,
    name character varying(255),
    value character varying(255),
    description character varying(255)
);


ALTER TABLE public.monarch_macros OWNER TO monarch;

--
-- Name: monarch_macros_macro_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE monarch_macros_macro_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.monarch_macros_macro_id_seq OWNER TO monarch;

--
-- Name: monarch_macros_macro_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE monarch_macros_macro_id_seq OWNED BY monarch_macros.macro_id;


--
-- Name: performanceconfig; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE performanceconfig (
    performanceconfig_id integer NOT NULL,
    host character varying(255) NOT NULL,
    service character varying(255) NOT NULL,
    type character varying(100) NOT NULL,
    enable smallint DEFAULT 0,
    parseregx_first smallint DEFAULT 0,
    service_regx smallint DEFAULT 0,
    label character varying(100) NOT NULL,
    rrdname character varying(100) NOT NULL,
    rrdcreatestring text NOT NULL,
    rrdupdatestring text NOT NULL,
    graphcgi text,
    perfidstring character varying(100) NOT NULL,
    parseregx character varying(255) NOT NULL
);


ALTER TABLE public.performanceconfig OWNER TO monarch;

--
-- Name: performanceconfig_performanceconfig_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE performanceconfig_performanceconfig_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.performanceconfig_performanceconfig_id_seq OWNER TO monarch;

--
-- Name: performanceconfig_performanceconfig_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE performanceconfig_performanceconfig_id_seq OWNED BY performanceconfig.performanceconfig_id;


--
-- Name: profile_host_profile_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE profile_host_profile_service (
    hostprofile_id integer DEFAULT 0 NOT NULL,
    serviceprofile_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.profile_host_profile_service OWNER TO monarch;

--
-- Name: profile_hostgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE profile_hostgroup (
    hostprofile_id integer DEFAULT 0 NOT NULL,
    hostgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.profile_hostgroup OWNER TO monarch;

--
-- Name: profile_parent; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE profile_parent (
    hostprofile_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.profile_parent OWNER TO monarch;

--
-- Name: profiles_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE profiles_host (
    hostprofile_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(255),
    host_template_id integer,
    host_extinfo_id integer,
    host_escalation_id integer,
    service_escalation_id integer,
    data text
);


ALTER TABLE public.profiles_host OWNER TO monarch;

--
-- Name: profiles_host_hostprofile_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE profiles_host_hostprofile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.profiles_host_hostprofile_id_seq OWNER TO monarch;

--
-- Name: profiles_host_hostprofile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE profiles_host_hostprofile_id_seq OWNED BY profiles_host.hostprofile_id;


--
-- Name: profiles_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE profiles_service (
    serviceprofile_id integer NOT NULL,
    name character varying(255),
    description character varying(100),
    data text
);


ALTER TABLE public.profiles_service OWNER TO monarch;

--
-- Name: profiles_service_serviceprofile_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE profiles_service_serviceprofile_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.profiles_service_serviceprofile_id_seq OWNER TO monarch;

--
-- Name: profiles_service_serviceprofile_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE profiles_service_serviceprofile_id_seq OWNED BY profiles_service.serviceprofile_id;


--
-- Name: service_dependency; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE service_dependency (
    id integer NOT NULL,
    service_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL,
    depend_on_host_id integer DEFAULT 0 NOT NULL,
    template integer DEFAULT 0 NOT NULL,
    comment text
);


ALTER TABLE public.service_dependency OWNER TO monarch;

--
-- Name: service_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE service_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_dependency_id_seq OWNER TO monarch;

--
-- Name: service_dependency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE service_dependency_id_seq OWNED BY service_dependency.id;


--
-- Name: service_dependency_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE service_dependency_templates (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL,
    data text,
    comment text
);


ALTER TABLE public.service_dependency_templates OWNER TO monarch;

--
-- Name: service_dependency_templates_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE service_dependency_templates_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_dependency_templates_id_seq OWNER TO monarch;

--
-- Name: service_dependency_templates_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE service_dependency_templates_id_seq OWNED BY service_dependency_templates.id;


--
-- Name: service_instance; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE service_instance (
    instance_id integer NOT NULL,
    service_id integer DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    status smallint DEFAULT 0,
    arguments character varying(508),
    externals_arguments text,
    inherit_ext_args smallint DEFAULT 1
);


ALTER TABLE public.service_instance OWNER TO monarch;

--
-- Name: service_instance_instance_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE service_instance_instance_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_instance_instance_id_seq OWNER TO monarch;

--
-- Name: service_instance_instance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE service_instance_instance_id_seq OWNED BY service_instance.instance_id;


--
-- Name: service_names; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE service_names (
    servicename_id integer NOT NULL,
    name character varying(255),
    description character varying(100),
    template integer,
    check_command integer,
    command_line text,
    escalation integer,
    extinfo integer,
    data text,
    externals_arguments text
);


ALTER TABLE public.service_names OWNER TO monarch;

--
-- Name: service_names_servicename_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE service_names_servicename_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_names_servicename_id_seq OWNER TO monarch;

--
-- Name: service_names_servicename_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE service_names_servicename_id_seq OWNED BY service_names.servicename_id;


--
-- Name: service_overrides; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE service_overrides (
    service_id integer DEFAULT 0 NOT NULL,
    check_period integer,
    notification_period integer,
    event_handler integer,
    data text
);


ALTER TABLE public.service_overrides OWNER TO monarch;

--
-- Name: service_templates; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE service_templates (
    servicetemplate_id integer NOT NULL,
    name character varying(255) NOT NULL,
    parent_id integer,
    check_period integer,
    notification_period integer,
    check_command integer,
    command_line text,
    event_handler integer,
    data text,
    comment text
);


ALTER TABLE public.service_templates OWNER TO monarch;

--
-- Name: service_templates_servicetemplate_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE service_templates_servicetemplate_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.service_templates_servicetemplate_id_seq OWNER TO monarch;

--
-- Name: service_templates_servicetemplate_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE service_templates_servicetemplate_id_seq OWNED BY service_templates.servicetemplate_id;


--
-- Name: servicegroup_service; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE servicegroup_service (
    servicegroup_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL,
    service_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.servicegroup_service OWNER TO monarch;

--
-- Name: servicegroups; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE servicegroups (
    servicegroup_id integer NOT NULL,
    name character varying(255) NOT NULL,
    alias character varying(255) NOT NULL,
    escalation_id integer,
    comment text,
    notes character varying(4096)
);


ALTER TABLE public.servicegroups OWNER TO monarch;

--
-- Name: servicegroups_servicegroup_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE servicegroups_servicegroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.servicegroups_servicegroup_id_seq OWNER TO monarch;

--
-- Name: servicegroups_servicegroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE servicegroups_servicegroup_id_seq OWNED BY servicegroups.servicegroup_id;


--
-- Name: servicename_dependency; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE servicename_dependency (
    id integer NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL,
    depend_on_host_id integer,
    template integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.servicename_dependency OWNER TO monarch;

--
-- Name: servicename_dependency_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE servicename_dependency_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.servicename_dependency_id_seq OWNER TO monarch;

--
-- Name: servicename_dependency_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE servicename_dependency_id_seq OWNED BY servicename_dependency.id;


--
-- Name: servicename_overrides; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE servicename_overrides (
    servicename_id integer DEFAULT 0 NOT NULL,
    check_period integer,
    notification_period integer,
    event_handler integer,
    data text
);


ALTER TABLE public.servicename_overrides OWNER TO monarch;

--
-- Name: serviceprofile; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE serviceprofile (
    servicename_id integer DEFAULT 0 NOT NULL,
    serviceprofile_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.serviceprofile OWNER TO monarch;

--
-- Name: serviceprofile_host; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE serviceprofile_host (
    serviceprofile_id integer DEFAULT 0 NOT NULL,
    host_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.serviceprofile_host OWNER TO monarch;

--
-- Name: serviceprofile_hostgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE serviceprofile_hostgroup (
    serviceprofile_id integer DEFAULT 0 NOT NULL,
    hostgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.serviceprofile_hostgroup OWNER TO monarch;

--
-- Name: services; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE services (
    service_id integer NOT NULL,
    host_id integer DEFAULT 0 NOT NULL,
    servicename_id integer DEFAULT 0 NOT NULL,
    servicetemplate_id integer,
    serviceextinfo_id integer,
    escalation_id integer,
    status smallint,
    check_command integer,
    command_line text,
    comment text,
    notes character varying(4096),
    externals_arguments text,
    inherit_ext_args smallint DEFAULT 1
);


ALTER TABLE public.services OWNER TO monarch;

--
-- Name: services_service_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE services_service_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.services_service_id_seq OWNER TO monarch;

--
-- Name: services_service_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE services_service_id_seq OWNED BY services.service_id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE sessions (
    id character(32) NOT NULL,
    a_session text NOT NULL
);


ALTER TABLE public.sessions OWNER TO monarch;

--
-- Name: setup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE setup (
    name character varying(255) NOT NULL,
    type character varying(50),
    value text
);


ALTER TABLE public.setup OWNER TO monarch;

--
-- Name: stage_host_hostgroups; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE stage_host_hostgroups (
    name character varying(255) NOT NULL,
    user_acct character varying(50) NOT NULL,
    hostgroup character varying(50) NOT NULL
);


ALTER TABLE public.stage_host_hostgroups OWNER TO monarch;

--
-- Name: stage_host_services; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE stage_host_services (
    name character varying(255) NOT NULL,
    user_acct character varying(50) NOT NULL,
    host character varying(255) NOT NULL,
    type character varying(20),
    status smallint,
    service_id integer
);


ALTER TABLE public.stage_host_services OWNER TO monarch;

--
-- Name: stage_hosts; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE stage_hosts (
    name character varying(255) NOT NULL,
    user_acct character varying(50) NOT NULL,
    type character varying(20),
    status smallint,
    alias character varying(255),
    address character varying(255),
    os character varying(50),
    hostprofile character varying(50),
    serviceprofile character varying(50),
    info character varying(50),
    notes character varying(4096)
);


ALTER TABLE public.stage_hosts OWNER TO monarch;

--
-- Name: stage_other; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE stage_other (
    name character varying(255) NOT NULL,
    type character varying(50) NOT NULL,
    parent character varying(255) NOT NULL,
    data text,
    comment text
);


ALTER TABLE public.stage_other OWNER TO monarch;

--
-- Name: time_period_exclude; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE time_period_exclude (
    timeperiod_id integer DEFAULT 0 NOT NULL,
    exclude_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.time_period_exclude OWNER TO monarch;

--
-- Name: time_period_property; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE time_period_property (
    timeperiod_id integer DEFAULT 0 NOT NULL,
    name character varying(255) NOT NULL,
    type character varying(255),
    value character varying(400),
    comment character varying(255)
);


ALTER TABLE public.time_period_property OWNER TO monarch;

--
-- Name: time_periods; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE time_periods (
    timeperiod_id integer NOT NULL,
    name character varying(255) NOT NULL,
    alias character varying(255) NOT NULL,
    comment text
);


ALTER TABLE public.time_periods OWNER TO monarch;

--
-- Name: time_periods_timeperiod_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE time_periods_timeperiod_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.time_periods_timeperiod_id_seq OWNER TO monarch;

--
-- Name: time_periods_timeperiod_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE time_periods_timeperiod_id_seq OWNED BY time_periods.timeperiod_id;


--
-- Name: tree_template_contactgroup; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE tree_template_contactgroup (
    tree_id integer DEFAULT 0 NOT NULL,
    template_id integer DEFAULT 0 NOT NULL,
    contactgroup_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.tree_template_contactgroup OWNER TO monarch;

--
-- Name: user_group; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE user_group (
    usergroup_id integer DEFAULT 0 NOT NULL,
    user_id integer DEFAULT 0 NOT NULL
);


ALTER TABLE public.user_group OWNER TO monarch;

--
-- Name: user_groups; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE user_groups (
    usergroup_id integer NOT NULL,
    name character varying(255) NOT NULL,
    description character varying(100)
);


ALTER TABLE public.user_groups OWNER TO monarch;

--
-- Name: user_groups_usergroup_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE user_groups_usergroup_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.user_groups_usergroup_id_seq OWNER TO monarch;

--
-- Name: user_groups_usergroup_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE user_groups_usergroup_id_seq OWNED BY user_groups.usergroup_id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: monarch; Tablespace: 
--

CREATE TABLE users (
    user_id integer NOT NULL,
    user_acct character varying(50) NOT NULL,
    user_name character varying(255) NOT NULL,
    password character varying(20) NOT NULL,
    session character varying(255)
);


ALTER TABLE public.users OWNER TO monarch;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: monarch
--

CREATE SEQUENCE users_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_user_id_seq OWNER TO monarch;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: monarch
--

ALTER SEQUENCE users_user_id_seq OWNED BY users.user_id;


--
-- Name: command_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE commands ALTER COLUMN command_id SET DEFAULT nextval('commands_command_id_seq'::regclass);


--
-- Name: contacttemplate_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE contact_templates ALTER COLUMN contacttemplate_id SET DEFAULT nextval('contact_templates_contacttemplate_id_seq'::regclass);


--
-- Name: contactgroup_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE contactgroups ALTER COLUMN contactgroup_id SET DEFAULT nextval('contactgroups_contactgroup_id_seq'::regclass);


--
-- Name: contact_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE contacts ALTER COLUMN contact_id SET DEFAULT nextval('contacts_contact_id_seq'::regclass);


--
-- Name: datatype_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE datatype ALTER COLUMN datatype_id SET DEFAULT nextval('datatype_datatype_id_seq'::regclass);


--
-- Name: filter_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE discover_filter ALTER COLUMN filter_id SET DEFAULT nextval('discover_filter_filter_id_seq'::regclass);


--
-- Name: group_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE discover_group ALTER COLUMN group_id SET DEFAULT nextval('discover_group_group_id_seq'::regclass);


--
-- Name: method_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE discover_method ALTER COLUMN method_id SET DEFAULT nextval('discover_method_method_id_seq'::regclass);


--
-- Name: template_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE escalation_templates ALTER COLUMN template_id SET DEFAULT nextval('escalation_templates_template_id_seq'::regclass);


--
-- Name: tree_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE escalation_trees ALTER COLUMN tree_id SET DEFAULT nextval('escalation_trees_tree_id_seq'::regclass);


--
-- Name: hostextinfo_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE extended_host_info_templates ALTER COLUMN hostextinfo_id SET DEFAULT nextval('extended_host_info_templates_hostextinfo_id_seq'::regclass);


--
-- Name: serviceextinfo_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE extended_service_info_templates ALTER COLUMN serviceextinfo_id SET DEFAULT nextval('extended_service_info_templates_serviceextinfo_id_seq'::regclass);


--
-- Name: external_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE externals ALTER COLUMN external_id SET DEFAULT nextval('externals_external_id_seq'::regclass);


--
-- Name: host_service_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE host_service ALTER COLUMN host_service_id SET DEFAULT nextval('host_service_host_service_id_seq'::regclass);


--
-- Name: hosttemplate_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE host_templates ALTER COLUMN hosttemplate_id SET DEFAULT nextval('host_templates_hosttemplate_id_seq'::regclass);


--
-- Name: hostgroup_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE hostgroups ALTER COLUMN hostgroup_id SET DEFAULT nextval('hostgroups_hostgroup_id_seq'::regclass);


--
-- Name: host_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE hosts ALTER COLUMN host_id SET DEFAULT nextval('hosts_host_id_seq'::regclass);


--
-- Name: column_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE import_column ALTER COLUMN column_id SET DEFAULT nextval('import_column_column_id_seq'::regclass);


--
-- Name: import_hosts_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE import_hosts ALTER COLUMN import_hosts_id SET DEFAULT nextval('import_hosts_import_hosts_id_seq'::regclass);


--
-- Name: match_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE import_match ALTER COLUMN match_id SET DEFAULT nextval('import_match_match_id_seq'::regclass);


--
-- Name: schema_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE import_schema ALTER COLUMN schema_id SET DEFAULT nextval('import_schema_schema_id_seq'::regclass);


--
-- Name: import_services_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE import_services ALTER COLUMN import_services_id SET DEFAULT nextval('import_services_import_services_id_seq'::regclass);


--
-- Name: prop_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE monarch_group_props ALTER COLUMN prop_id SET DEFAULT nextval('monarch_group_props_prop_id_seq'::regclass);


--
-- Name: group_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE monarch_groups ALTER COLUMN group_id SET DEFAULT nextval('monarch_groups_group_id_seq'::regclass);


--
-- Name: macro_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE monarch_macros ALTER COLUMN macro_id SET DEFAULT nextval('monarch_macros_macro_id_seq'::regclass);


--
-- Name: performanceconfig_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE performanceconfig ALTER COLUMN performanceconfig_id SET DEFAULT nextval('performanceconfig_performanceconfig_id_seq'::regclass);


--
-- Name: hostprofile_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE profiles_host ALTER COLUMN hostprofile_id SET DEFAULT nextval('profiles_host_hostprofile_id_seq'::regclass);


--
-- Name: serviceprofile_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE profiles_service ALTER COLUMN serviceprofile_id SET DEFAULT nextval('profiles_service_serviceprofile_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE service_dependency ALTER COLUMN id SET DEFAULT nextval('service_dependency_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE service_dependency_templates ALTER COLUMN id SET DEFAULT nextval('service_dependency_templates_id_seq'::regclass);


--
-- Name: instance_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE service_instance ALTER COLUMN instance_id SET DEFAULT nextval('service_instance_instance_id_seq'::regclass);


--
-- Name: servicename_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE service_names ALTER COLUMN servicename_id SET DEFAULT nextval('service_names_servicename_id_seq'::regclass);


--
-- Name: servicetemplate_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE service_templates ALTER COLUMN servicetemplate_id SET DEFAULT nextval('service_templates_servicetemplate_id_seq'::regclass);


--
-- Name: servicegroup_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE servicegroups ALTER COLUMN servicegroup_id SET DEFAULT nextval('servicegroups_servicegroup_id_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE servicename_dependency ALTER COLUMN id SET DEFAULT nextval('servicename_dependency_id_seq'::regclass);


--
-- Name: service_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE services ALTER COLUMN service_id SET DEFAULT nextval('services_service_id_seq'::regclass);


--
-- Name: timeperiod_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE time_periods ALTER COLUMN timeperiod_id SET DEFAULT nextval('time_periods_timeperiod_id_seq'::regclass);


--
-- Name: usergroup_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE user_groups ALTER COLUMN usergroup_id SET DEFAULT nextval('user_groups_usergroup_id_seq'::regclass);


--
-- Name: user_id; Type: DEFAULT; Schema: public; Owner: monarch
--

ALTER TABLE users ALTER COLUMN user_id SET DEFAULT nextval('users_user_id_seq'::regclass);


--
-- Name: access_list_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY access_list
    ADD CONSTRAINT access_list_pkey PRIMARY KEY (object, type, usergroup_id);


--
-- Name: commands_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY commands
    ADD CONSTRAINT commands_name_key UNIQUE (name);


--
-- Name: commands_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY commands
    ADD CONSTRAINT commands_pkey PRIMARY KEY (command_id);


--
-- Name: contact_command_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_command_overrides
    ADD CONSTRAINT contact_command_overrides_pkey PRIMARY KEY (contact_id, type, command_id);


--
-- Name: contact_command_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_command
    ADD CONSTRAINT contact_command_pkey PRIMARY KEY (contacttemplate_id, type, command_id);


--
-- Name: contact_group_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_group
    ADD CONSTRAINT contact_group_pkey PRIMARY KEY (contact_id, group_id);


--
-- Name: contact_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_host
    ADD CONSTRAINT contact_host_pkey PRIMARY KEY (contact_id, host_id);


--
-- Name: contact_host_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_host_profile
    ADD CONSTRAINT contact_host_profile_pkey PRIMARY KEY (contact_id, hostprofile_id);


--
-- Name: contact_host_template_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_host_template
    ADD CONSTRAINT contact_host_template_pkey PRIMARY KEY (contact_id, hosttemplate_id);


--
-- Name: contact_hostgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_hostgroup
    ADD CONSTRAINT contact_hostgroup_pkey PRIMARY KEY (contact_id, hostgroup_id);


--
-- Name: contact_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_overrides
    ADD CONSTRAINT contact_overrides_pkey PRIMARY KEY (contact_id);


--
-- Name: contact_service_name_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_service_name
    ADD CONSTRAINT contact_service_name_pkey PRIMARY KEY (contact_id, servicename_id);


--
-- Name: contact_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_service
    ADD CONSTRAINT contact_service_pkey PRIMARY KEY (contact_id, service_id);


--
-- Name: contact_service_template_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_service_template
    ADD CONSTRAINT contact_service_template_pkey PRIMARY KEY (contact_id, servicetemplate_id);


--
-- Name: contact_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_templates
    ADD CONSTRAINT contact_templates_name_key UNIQUE (name);


--
-- Name: contact_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contact_templates
    ADD CONSTRAINT contact_templates_pkey PRIMARY KEY (contacttemplate_id);


--
-- Name: contactgroup_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_contact
    ADD CONSTRAINT contactgroup_contact_pkey PRIMARY KEY (contactgroup_id, contact_id);


--
-- Name: contactgroup_group_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_group
    ADD CONSTRAINT contactgroup_group_pkey PRIMARY KEY (contactgroup_id, group_id);


--
-- Name: contactgroup_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_host
    ADD CONSTRAINT contactgroup_host_pkey PRIMARY KEY (contactgroup_id, host_id);


--
-- Name: contactgroup_host_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_host_profile
    ADD CONSTRAINT contactgroup_host_profile_pkey PRIMARY KEY (contactgroup_id, hostprofile_id);


--
-- Name: contactgroup_host_template_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_host_template
    ADD CONSTRAINT contactgroup_host_template_pkey PRIMARY KEY (contactgroup_id, hosttemplate_id);


--
-- Name: contactgroup_hostgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_hostgroup
    ADD CONSTRAINT contactgroup_hostgroup_pkey PRIMARY KEY (contactgroup_id, hostgroup_id);


--
-- Name: contactgroup_service_name_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_service_name
    ADD CONSTRAINT contactgroup_service_name_pkey PRIMARY KEY (contactgroup_id, servicename_id);


--
-- Name: contactgroup_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_service
    ADD CONSTRAINT contactgroup_service_pkey PRIMARY KEY (contactgroup_id, service_id);


--
-- Name: contactgroup_service_template_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroup_service_template
    ADD CONSTRAINT contactgroup_service_template_pkey PRIMARY KEY (contactgroup_id, servicetemplate_id);


--
-- Name: contactgroups_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroups
    ADD CONSTRAINT contactgroups_name_key UNIQUE (name);


--
-- Name: contactgroups_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contactgroups
    ADD CONSTRAINT contactgroups_pkey PRIMARY KEY (contactgroup_id);


--
-- Name: contacts_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_name_key UNIQUE (name);


--
-- Name: contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (contact_id);


--
-- Name: datatype_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY datatype
    ADD CONSTRAINT datatype_pkey PRIMARY KEY (datatype_id);


--
-- Name: discover_filter_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY discover_filter
    ADD CONSTRAINT discover_filter_pkey PRIMARY KEY (filter_id);


--
-- Name: discover_group_filter_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY discover_group_filter
    ADD CONSTRAINT discover_group_filter_pkey PRIMARY KEY (group_id, filter_id);


--
-- Name: discover_group_method_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY discover_group_method
    ADD CONSTRAINT discover_group_method_pkey PRIMARY KEY (group_id, method_id);


--
-- Name: discover_group_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY discover_group
    ADD CONSTRAINT discover_group_pkey PRIMARY KEY (group_id);


--
-- Name: discover_method_filter_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY discover_method_filter
    ADD CONSTRAINT discover_method_filter_pkey PRIMARY KEY (method_id, filter_id);


--
-- Name: discover_method_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY discover_method
    ADD CONSTRAINT discover_method_pkey PRIMARY KEY (method_id);


--
-- Name: escalation_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY escalation_templates
    ADD CONSTRAINT escalation_templates_name_key UNIQUE (name);


--
-- Name: escalation_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY escalation_templates
    ADD CONSTRAINT escalation_templates_pkey PRIMARY KEY (template_id);


--
-- Name: escalation_tree_template_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY escalation_tree_template
    ADD CONSTRAINT escalation_tree_template_pkey PRIMARY KEY (tree_id, template_id);


--
-- Name: escalation_trees_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY escalation_trees
    ADD CONSTRAINT escalation_trees_name_key UNIQUE (name);


--
-- Name: escalation_trees_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY escalation_trees
    ADD CONSTRAINT escalation_trees_pkey PRIMARY KEY (tree_id);


--
-- Name: extended_host_info_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY extended_host_info_templates
    ADD CONSTRAINT extended_host_info_templates_name_key UNIQUE (name);


--
-- Name: extended_host_info_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY extended_host_info_templates
    ADD CONSTRAINT extended_host_info_templates_pkey PRIMARY KEY (hostextinfo_id);


--
-- Name: extended_info_coords_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY extended_info_coords
    ADD CONSTRAINT extended_info_coords_pkey PRIMARY KEY (host_id);


--
-- Name: extended_service_info_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY extended_service_info_templates
    ADD CONSTRAINT extended_service_info_templates_name_key UNIQUE (name);


--
-- Name: extended_service_info_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY extended_service_info_templates
    ADD CONSTRAINT extended_service_info_templates_pkey PRIMARY KEY (serviceextinfo_id);


--
-- Name: external_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY external_host
    ADD CONSTRAINT external_host_pkey PRIMARY KEY (external_id, host_id);


--
-- Name: external_host_profile_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY external_host_profile
    ADD CONSTRAINT external_host_profile_pkey PRIMARY KEY (external_id, hostprofile_id);


--
-- Name: external_service_names_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY external_service_names
    ADD CONSTRAINT external_service_names_pkey PRIMARY KEY (external_id, servicename_id);


--
-- Name: external_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY external_service
    ADD CONSTRAINT external_service_pkey PRIMARY KEY (external_id, host_id, service_id);


--
-- Name: externals_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY externals
    ADD CONSTRAINT externals_pkey PRIMARY KEY (external_id);


--
-- Name: host_dependencies_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY host_dependencies
    ADD CONSTRAINT host_dependencies_pkey PRIMARY KEY (host_id, parent_id);


--
-- Name: host_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY host_overrides
    ADD CONSTRAINT host_overrides_pkey PRIMARY KEY (host_id);


--
-- Name: host_parent_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY host_parent
    ADD CONSTRAINT host_parent_pkey PRIMARY KEY (host_id, parent_id);


--
-- Name: host_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY host_service
    ADD CONSTRAINT host_service_pkey PRIMARY KEY (host_service_id);


--
-- Name: host_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY host_templates
    ADD CONSTRAINT host_templates_name_key UNIQUE (name);


--
-- Name: host_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY host_templates
    ADD CONSTRAINT host_templates_pkey PRIMARY KEY (hosttemplate_id);


--
-- Name: hostgroup_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY hostgroup_host
    ADD CONSTRAINT hostgroup_host_pkey PRIMARY KEY (hostgroup_id, host_id);


--
-- Name: hostgroups_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY hostgroups
    ADD CONSTRAINT hostgroups_name_key UNIQUE (name);


--
-- Name: hostgroups_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY hostgroups
    ADD CONSTRAINT hostgroups_pkey PRIMARY KEY (hostgroup_id);


--
-- Name: hostprofile_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY hostprofile_overrides
    ADD CONSTRAINT hostprofile_overrides_pkey PRIMARY KEY (hostprofile_id);


--
-- Name: hosts_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_name_key UNIQUE (name);


--
-- Name: hosts_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_pkey PRIMARY KEY (host_id);


--
-- Name: import_column_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_column
    ADD CONSTRAINT import_column_pkey PRIMARY KEY (column_id);


--
-- Name: import_hosts_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_hosts
    ADD CONSTRAINT import_hosts_name_key UNIQUE (name);


--
-- Name: import_hosts_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_hosts
    ADD CONSTRAINT import_hosts_pkey PRIMARY KEY (import_hosts_id);


--
-- Name: import_match_contactgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match_contactgroup
    ADD CONSTRAINT import_match_contactgroup_pkey PRIMARY KEY (match_id, contactgroup_id);


--
-- Name: import_match_group_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match_group
    ADD CONSTRAINT import_match_group_pkey PRIMARY KEY (match_id, group_id);


--
-- Name: import_match_hostgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match_hostgroup
    ADD CONSTRAINT import_match_hostgroup_pkey PRIMARY KEY (match_id, hostgroup_id);


--
-- Name: import_match_parent_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match_parent
    ADD CONSTRAINT import_match_parent_pkey PRIMARY KEY (match_id, parent_id);


--
-- Name: import_match_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match
    ADD CONSTRAINT import_match_pkey PRIMARY KEY (match_id);


--
-- Name: import_match_servicename_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match_servicename
    ADD CONSTRAINT import_match_servicename_pkey PRIMARY KEY (match_id, servicename_id);


--
-- Name: import_match_serviceprofile_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_match_serviceprofile
    ADD CONSTRAINT import_match_serviceprofile_pkey PRIMARY KEY (match_id, serviceprofile_id);


--
-- Name: import_schema_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_schema
    ADD CONSTRAINT import_schema_pkey PRIMARY KEY (schema_id);


--
-- Name: import_services_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY import_services
    ADD CONSTRAINT import_services_pkey PRIMARY KEY (import_services_id);


--
-- Name: monarch_group_child_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_group_child
    ADD CONSTRAINT monarch_group_child_pkey PRIMARY KEY (group_id, child_id);


--
-- Name: monarch_group_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_group_host
    ADD CONSTRAINT monarch_group_host_pkey PRIMARY KEY (group_id, host_id);


--
-- Name: monarch_group_hostgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_group_hostgroup
    ADD CONSTRAINT monarch_group_hostgroup_pkey PRIMARY KEY (group_id, hostgroup_id);


--
-- Name: monarch_group_macro_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_group_macro
    ADD CONSTRAINT monarch_group_macro_pkey PRIMARY KEY (group_id, macro_id);


--
-- Name: monarch_group_props_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_group_props
    ADD CONSTRAINT monarch_group_props_pkey PRIMARY KEY (prop_id);


--
-- Name: monarch_groups_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_groups
    ADD CONSTRAINT monarch_groups_name_key UNIQUE (name);


--
-- Name: monarch_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_groups
    ADD CONSTRAINT monarch_groups_pkey PRIMARY KEY (group_id);


--
-- Name: monarch_macros_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY monarch_macros
    ADD CONSTRAINT monarch_macros_pkey PRIMARY KEY (macro_id);


--
-- Name: performanceconfig_host_service_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY performanceconfig
    ADD CONSTRAINT performanceconfig_host_service_key UNIQUE (host, service);


--
-- Name: performanceconfig_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY performanceconfig
    ADD CONSTRAINT performanceconfig_pkey PRIMARY KEY (performanceconfig_id);


--
-- Name: profile_host_profile_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profile_host_profile_service
    ADD CONSTRAINT profile_host_profile_service_pkey PRIMARY KEY (hostprofile_id, serviceprofile_id);


--
-- Name: profile_hostgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profile_hostgroup
    ADD CONSTRAINT profile_hostgroup_pkey PRIMARY KEY (hostprofile_id, hostgroup_id);


--
-- Name: profile_parent_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profile_parent
    ADD CONSTRAINT profile_parent_pkey PRIMARY KEY (hostprofile_id, host_id);


--
-- Name: profiles_host_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profiles_host
    ADD CONSTRAINT profiles_host_name_key UNIQUE (name);


--
-- Name: profiles_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profiles_host
    ADD CONSTRAINT profiles_host_pkey PRIMARY KEY (hostprofile_id);


--
-- Name: profiles_service_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profiles_service
    ADD CONSTRAINT profiles_service_name_key UNIQUE (name);


--
-- Name: profiles_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY profiles_service
    ADD CONSTRAINT profiles_service_pkey PRIMARY KEY (serviceprofile_id);


--
-- Name: service_dependency_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_dependency
    ADD CONSTRAINT service_dependency_pkey PRIMARY KEY (id);


--
-- Name: service_dependency_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_dependency_templates
    ADD CONSTRAINT service_dependency_templates_name_key UNIQUE (name);


--
-- Name: service_dependency_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_dependency_templates
    ADD CONSTRAINT service_dependency_templates_pkey PRIMARY KEY (id);


--
-- Name: service_instance_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_instance
    ADD CONSTRAINT service_instance_pkey PRIMARY KEY (instance_id);


--
-- Name: service_instance_service_id_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_instance
    ADD CONSTRAINT service_instance_service_id_name_key UNIQUE (service_id, name);


--
-- Name: service_names_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_names
    ADD CONSTRAINT service_names_name_key UNIQUE (name);


--
-- Name: service_names_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_names
    ADD CONSTRAINT service_names_pkey PRIMARY KEY (servicename_id);


--
-- Name: service_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_overrides
    ADD CONSTRAINT service_overrides_pkey PRIMARY KEY (service_id);


--
-- Name: service_templates_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_templates
    ADD CONSTRAINT service_templates_name_key UNIQUE (name);


--
-- Name: service_templates_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY service_templates
    ADD CONSTRAINT service_templates_pkey PRIMARY KEY (servicetemplate_id);


--
-- Name: servicegroup_service_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY servicegroup_service
    ADD CONSTRAINT servicegroup_service_pkey PRIMARY KEY (servicegroup_id, host_id, service_id);


--
-- Name: servicegroups_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY servicegroups
    ADD CONSTRAINT servicegroups_name_key UNIQUE (name);


--
-- Name: servicegroups_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY servicegroups
    ADD CONSTRAINT servicegroups_pkey PRIMARY KEY (servicegroup_id);


--
-- Name: servicename_dependency_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY servicename_dependency
    ADD CONSTRAINT servicename_dependency_pkey PRIMARY KEY (id);


--
-- Name: servicename_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY servicename_overrides
    ADD CONSTRAINT servicename_overrides_pkey PRIMARY KEY (servicename_id);


--
-- Name: serviceprofile_host_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY serviceprofile_host
    ADD CONSTRAINT serviceprofile_host_pkey PRIMARY KEY (serviceprofile_id, host_id);


--
-- Name: serviceprofile_hostgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY serviceprofile_hostgroup
    ADD CONSTRAINT serviceprofile_hostgroup_pkey PRIMARY KEY (serviceprofile_id, hostgroup_id);


--
-- Name: serviceprofile_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY serviceprofile
    ADD CONSTRAINT serviceprofile_pkey PRIMARY KEY (servicename_id, serviceprofile_id);


--
-- Name: services_host_id_servicename_id_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_host_id_servicename_id_key UNIQUE (host_id, servicename_id);


--
-- Name: services_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_pkey PRIMARY KEY (service_id);


--
-- Name: sessions_id_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_id_key UNIQUE (id);


--
-- Name: setup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY setup
    ADD CONSTRAINT setup_pkey PRIMARY KEY (name);


--
-- Name: stage_host_hostgroups_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY stage_host_hostgroups
    ADD CONSTRAINT stage_host_hostgroups_pkey PRIMARY KEY (name, user_acct, hostgroup);


--
-- Name: stage_host_services_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY stage_host_services
    ADD CONSTRAINT stage_host_services_pkey PRIMARY KEY (name, user_acct, host);


--
-- Name: stage_hosts_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY stage_hosts
    ADD CONSTRAINT stage_hosts_pkey PRIMARY KEY (name, user_acct);


--
-- Name: stage_other_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY stage_other
    ADD CONSTRAINT stage_other_pkey PRIMARY KEY (name, type, parent);


--
-- Name: time_period_exclude_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY time_period_exclude
    ADD CONSTRAINT time_period_exclude_pkey PRIMARY KEY (timeperiod_id, exclude_id);


--
-- Name: time_period_property_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY time_period_property
    ADD CONSTRAINT time_period_property_pkey PRIMARY KEY (timeperiod_id, name);


--
-- Name: time_periods_name_key; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY time_periods
    ADD CONSTRAINT time_periods_name_key UNIQUE (name);


--
-- Name: time_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY time_periods
    ADD CONSTRAINT time_periods_pkey PRIMARY KEY (timeperiod_id);


--
-- Name: tree_template_contactgroup_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY tree_template_contactgroup
    ADD CONSTRAINT tree_template_contactgroup_pkey PRIMARY KEY (tree_id, template_id, contactgroup_id);


--
-- Name: user_group_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY user_group
    ADD CONSTRAINT user_group_pkey PRIMARY KEY (usergroup_id, user_id);


--
-- Name: user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY user_groups
    ADD CONSTRAINT user_groups_pkey PRIMARY KEY (usergroup_id);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: monarch; Tablespace: 
--

ALTER TABLE ONLY users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: access_list_usergroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX access_list_usergroup_id ON access_list USING btree (usergroup_id);


--
-- Name: contact_command_command_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_command_command_id ON contact_command USING btree (command_id);


--
-- Name: contact_command_overrides_command_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_command_overrides_command_id ON contact_command_overrides USING btree (command_id);


--
-- Name: contact_group_group_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_group_group_id ON contact_group USING btree (group_id);


--
-- Name: contact_host_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_host_host_id ON contact_host USING btree (host_id);


--
-- Name: contact_host_profile_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_host_profile_hostprofile_id ON contact_host_profile USING btree (hostprofile_id);


--
-- Name: contact_host_template_hosttemplate_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_host_template_hosttemplate_id ON contact_host_template USING btree (hosttemplate_id);


--
-- Name: contact_hostgroup_hostgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_hostgroup_hostgroup_id ON contact_hostgroup USING btree (hostgroup_id);


--
-- Name: contact_service_name_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_service_name_servicename_id ON contact_service_name USING btree (servicename_id);


--
-- Name: contact_service_service_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_service_service_id ON contact_service USING btree (service_id);


--
-- Name: contact_service_template_servicetemplate_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contact_service_template_servicetemplate_id ON contact_service_template USING btree (servicetemplate_id);


--
-- Name: contactgroup_contact_contact_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_contact_contact_id ON contactgroup_contact USING btree (contact_id);


--
-- Name: contactgroup_group_group_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_group_group_id ON contactgroup_group USING btree (group_id);


--
-- Name: contactgroup_host_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_host_host_id ON contactgroup_host USING btree (host_id);


--
-- Name: contactgroup_host_profile_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_host_profile_hostprofile_id ON contactgroup_host_profile USING btree (hostprofile_id);


--
-- Name: contactgroup_host_template_hosttemplate_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_host_template_hosttemplate_id ON contactgroup_host_template USING btree (hosttemplate_id);


--
-- Name: contactgroup_hostgroup_hostgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_hostgroup_hostgroup_id ON contactgroup_hostgroup USING btree (hostgroup_id);


--
-- Name: contactgroup_service_name_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_service_name_servicename_id ON contactgroup_service_name USING btree (servicename_id);


--
-- Name: contactgroup_service_service_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_service_service_id ON contactgroup_service USING btree (service_id);


--
-- Name: contactgroup_service_template_servicetemplate_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX contactgroup_service_template_servicetemplate_id ON contactgroup_service_template USING btree (servicetemplate_id);


--
-- Name: discover_group_filter_filter_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX discover_group_filter_filter_id ON discover_group_filter USING btree (filter_id);


--
-- Name: discover_group_method_method_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX discover_group_method_method_id ON discover_group_method USING btree (method_id);


--
-- Name: discover_group_schema_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX discover_group_schema_id ON discover_group USING btree (schema_id);


--
-- Name: discover_method_filter_filter_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX discover_method_filter_filter_id ON discover_method_filter USING btree (filter_id);


--
-- Name: escalation_templates_escalation_period; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX escalation_templates_escalation_period ON escalation_templates USING btree (escalation_period);


--
-- Name: escalation_tree_template_template_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX escalation_tree_template_template_id ON escalation_tree_template USING btree (template_id);


--
-- Name: external_host_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX external_host_host_id ON external_host USING btree (host_id);


--
-- Name: external_host_profile_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX external_host_profile_hostprofile_id ON external_host_profile USING btree (hostprofile_id);


--
-- Name: external_service_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX external_service_host_id ON external_service USING btree (host_id);


--
-- Name: external_service_names_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX external_service_names_servicename_id ON external_service_names USING btree (servicename_id);


--
-- Name: external_service_service_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX external_service_service_id ON external_service USING btree (service_id);


--
-- Name: host_dependencies_parent_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX host_dependencies_parent_id ON host_dependencies USING btree (parent_id);


--
-- Name: host_parent_parent_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX host_parent_parent_id ON host_parent USING btree (parent_id);


--
-- Name: hostgroup_host_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hostgroup_host_host_id ON hostgroup_host USING btree (host_id);


--
-- Name: hostgroups_host_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hostgroups_host_escalation_id ON hostgroups USING btree (host_escalation_id);


--
-- Name: hostgroups_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hostgroups_hostprofile_id ON hostgroups USING btree (hostprofile_id);


--
-- Name: hostgroups_service_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hostgroups_service_escalation_id ON hostgroups USING btree (service_escalation_id);


--
-- Name: hosts_host_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hosts_host_escalation_id ON hosts USING btree (host_escalation_id);


--
-- Name: hosts_hostextinfo_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hosts_hostextinfo_id ON hosts USING btree (hostextinfo_id);


--
-- Name: hosts_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hosts_hostprofile_id ON hosts USING btree (hostprofile_id);


--
-- Name: hosts_service_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX hosts_service_escalation_id ON hosts USING btree (service_escalation_id);


--
-- Name: import_column_schema_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_column_schema_id ON import_column USING btree (schema_id);


--
-- Name: import_match_column_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_column_id ON import_match USING btree (column_id);


--
-- Name: import_match_contactgroup_contactgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_contactgroup_contactgroup_id ON import_match_contactgroup USING btree (contactgroup_id);


--
-- Name: import_match_group_group_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_group_group_id ON import_match_group USING btree (group_id);


--
-- Name: import_match_hostgroup_hostgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_hostgroup_hostgroup_id ON import_match_hostgroup USING btree (hostgroup_id);


--
-- Name: import_match_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_hostprofile_id ON import_match USING btree (hostprofile_id);


--
-- Name: import_match_parent_parent_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_parent_parent_id ON import_match_parent USING btree (parent_id);


--
-- Name: import_match_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_servicename_id ON import_match USING btree (servicename_id);


--
-- Name: import_match_servicename_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_servicename_servicename_id ON import_match_servicename USING btree (servicename_id);


--
-- Name: import_match_serviceprofile_serviceprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_match_serviceprofile_serviceprofile_id ON import_match_serviceprofile USING btree (serviceprofile_id);


--
-- Name: import_schema_hostprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX import_schema_hostprofile_id ON import_schema USING btree (hostprofile_id);


--
-- Name: monarch_group_child_child_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX monarch_group_child_child_id ON monarch_group_child USING btree (child_id);


--
-- Name: monarch_group_host_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX monarch_group_host_host_id ON monarch_group_host USING btree (host_id);


--
-- Name: monarch_group_hostgroup_hostgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX monarch_group_hostgroup_hostgroup_id ON monarch_group_hostgroup USING btree (hostgroup_id);


--
-- Name: monarch_group_macro_macro_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX monarch_group_macro_macro_id ON monarch_group_macro USING btree (macro_id);


--
-- Name: monarch_group_props_group_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX monarch_group_props_group_id ON monarch_group_props USING btree (group_id);


--
-- Name: profile_host_profile_service_serviceprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX profile_host_profile_service_serviceprofile_id ON profile_host_profile_service USING btree (serviceprofile_id);


--
-- Name: profile_hostgroup_hostgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX profile_hostgroup_hostgroup_id ON profile_hostgroup USING btree (hostgroup_id);


--
-- Name: profile_parent_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX profile_parent_host_id ON profile_parent USING btree (host_id);


--
-- Name: profiles_host_host_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX profiles_host_host_escalation_id ON profiles_host USING btree (host_escalation_id);


--
-- Name: profiles_host_host_extinfo_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX profiles_host_host_extinfo_id ON profiles_host USING btree (host_extinfo_id);


--
-- Name: profiles_host_service_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX profiles_host_service_escalation_id ON profiles_host USING btree (service_escalation_id);


--
-- Name: service_dependency_depend_on_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX service_dependency_depend_on_host_id ON service_dependency USING btree (depend_on_host_id);


--
-- Name: service_dependency_service_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX service_dependency_service_id ON service_dependency USING btree (service_id);


--
-- Name: service_names_escalation; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX service_names_escalation ON service_names USING btree (escalation);


--
-- Name: service_names_extinfo; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX service_names_extinfo ON service_names USING btree (extinfo);


--
-- Name: servicegroup_service_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX servicegroup_service_host_id ON servicegroup_service USING btree (host_id);


--
-- Name: servicegroup_service_service_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX servicegroup_service_service_id ON servicegroup_service USING btree (service_id);


--
-- Name: servicegroups_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX servicegroups_escalation_id ON servicegroups USING btree (escalation_id);


--
-- Name: servicename_dependency_depend_on_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX servicename_dependency_depend_on_host_id ON servicename_dependency USING btree (depend_on_host_id);


--
-- Name: servicename_dependency_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX servicename_dependency_servicename_id ON servicename_dependency USING btree (servicename_id);


--
-- Name: serviceprofile_host_host_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX serviceprofile_host_host_id ON serviceprofile_host USING btree (host_id);


--
-- Name: serviceprofile_hostgroup_hostgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX serviceprofile_hostgroup_hostgroup_id ON serviceprofile_hostgroup USING btree (hostgroup_id);


--
-- Name: serviceprofile_serviceprofile_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX serviceprofile_serviceprofile_id ON serviceprofile USING btree (serviceprofile_id);


--
-- Name: services_escalation_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX services_escalation_id ON services USING btree (escalation_id);


--
-- Name: services_serviceextinfo_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX services_serviceextinfo_id ON services USING btree (serviceextinfo_id);


--
-- Name: services_servicename_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX services_servicename_id ON services USING btree (servicename_id);


--
-- Name: time_period_exclude_exclude_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX time_period_exclude_exclude_id ON time_period_exclude USING btree (exclude_id);


--
-- Name: tree_template_contactgroup_contactgroup_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX tree_template_contactgroup_contactgroup_id ON tree_template_contactgroup USING btree (contactgroup_id);


--
-- Name: tree_template_contactgroup_template_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX tree_template_contactgroup_template_id ON tree_template_contactgroup USING btree (template_id);


--
-- Name: user_group_user_id; Type: INDEX; Schema: public; Owner: monarch; Tablespace: 
--

CREATE INDEX user_group_user_id ON user_group USING btree (user_id);


--
-- Name: access_list_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY access_list
    ADD CONSTRAINT access_list_ibfk_1 FOREIGN KEY (usergroup_id) REFERENCES user_groups(usergroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_command_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_command
    ADD CONSTRAINT contact_command_ibfk_1 FOREIGN KEY (command_id) REFERENCES commands(command_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_command_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_command
    ADD CONSTRAINT contact_command_ibfk_2 FOREIGN KEY (contacttemplate_id) REFERENCES contact_templates(contacttemplate_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_command_overrides_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_command_overrides
    ADD CONSTRAINT contact_command_overrides_ibfk_1 FOREIGN KEY (command_id) REFERENCES commands(command_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_command_overrides_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_command_overrides
    ADD CONSTRAINT contact_command_overrides_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_group_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_group
    ADD CONSTRAINT contact_group_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_group_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_group
    ADD CONSTRAINT contact_group_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_host
    ADD CONSTRAINT contact_host_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_host
    ADD CONSTRAINT contact_host_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_host_profile_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_host_profile
    ADD CONSTRAINT contact_host_profile_ibfk_1 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_host_profile_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_host_profile
    ADD CONSTRAINT contact_host_profile_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_host_template_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_host_template
    ADD CONSTRAINT contact_host_template_ibfk_1 FOREIGN KEY (hosttemplate_id) REFERENCES host_templates(hosttemplate_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_host_template_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_host_template
    ADD CONSTRAINT contact_host_template_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_hostgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_hostgroup
    ADD CONSTRAINT contact_hostgroup_ibfk_1 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_hostgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_hostgroup
    ADD CONSTRAINT contact_hostgroup_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_overrides_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_overrides
    ADD CONSTRAINT contact_overrides_ibfk_1 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_service_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_service
    ADD CONSTRAINT contact_service_ibfk_1 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_service_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_service
    ADD CONSTRAINT contact_service_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_service_name_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_service_name
    ADD CONSTRAINT contact_service_name_ibfk_1 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_service_name_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_service_name
    ADD CONSTRAINT contact_service_name_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_service_template_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_service_template
    ADD CONSTRAINT contact_service_template_ibfk_1 FOREIGN KEY (servicetemplate_id) REFERENCES service_templates(servicetemplate_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contact_service_template_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contact_service_template
    ADD CONSTRAINT contact_service_template_ibfk_2 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_contact_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_contact
    ADD CONSTRAINT contactgroup_contact_ibfk_1 FOREIGN KEY (contact_id) REFERENCES contacts(contact_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_contact_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_contact
    ADD CONSTRAINT contactgroup_contact_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_group_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_group
    ADD CONSTRAINT contactgroup_group_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_group_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_group
    ADD CONSTRAINT contactgroup_group_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_host
    ADD CONSTRAINT contactgroup_host_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_host
    ADD CONSTRAINT contactgroup_host_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_host_profile_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_host_profile
    ADD CONSTRAINT contactgroup_host_profile_ibfk_1 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_host_profile_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_host_profile
    ADD CONSTRAINT contactgroup_host_profile_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_host_template_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_host_template
    ADD CONSTRAINT contactgroup_host_template_ibfk_1 FOREIGN KEY (hosttemplate_id) REFERENCES host_templates(hosttemplate_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_host_template_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_host_template
    ADD CONSTRAINT contactgroup_host_template_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_hostgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_hostgroup
    ADD CONSTRAINT contactgroup_hostgroup_ibfk_1 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_hostgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_hostgroup
    ADD CONSTRAINT contactgroup_hostgroup_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_service_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_service
    ADD CONSTRAINT contactgroup_service_ibfk_1 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_service_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_service
    ADD CONSTRAINT contactgroup_service_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_service_name_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_service_name
    ADD CONSTRAINT contactgroup_service_name_ibfk_1 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_service_name_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_service_name
    ADD CONSTRAINT contactgroup_service_name_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_service_template_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_service_template
    ADD CONSTRAINT contactgroup_service_template_ibfk_1 FOREIGN KEY (servicetemplate_id) REFERENCES service_templates(servicetemplate_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: contactgroup_service_template_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY contactgroup_service_template
    ADD CONSTRAINT contactgroup_service_template_ibfk_2 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_group_filter_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_group_filter
    ADD CONSTRAINT discover_group_filter_ibfk_1 FOREIGN KEY (group_id) REFERENCES discover_group(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_group_filter_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_group_filter
    ADD CONSTRAINT discover_group_filter_ibfk_2 FOREIGN KEY (filter_id) REFERENCES discover_filter(filter_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_group_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_group
    ADD CONSTRAINT discover_group_ibfk_1 FOREIGN KEY (schema_id) REFERENCES import_schema(schema_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_group_method_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_group_method
    ADD CONSTRAINT discover_group_method_ibfk_1 FOREIGN KEY (method_id) REFERENCES discover_method(method_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_group_method_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_group_method
    ADD CONSTRAINT discover_group_method_ibfk_2 FOREIGN KEY (group_id) REFERENCES discover_group(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_method_filter_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_method_filter
    ADD CONSTRAINT discover_method_filter_ibfk_1 FOREIGN KEY (method_id) REFERENCES discover_method(method_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: discover_method_filter_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY discover_method_filter
    ADD CONSTRAINT discover_method_filter_ibfk_2 FOREIGN KEY (filter_id) REFERENCES discover_filter(filter_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: escalation_templates_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY escalation_templates
    ADD CONSTRAINT escalation_templates_ibfk_1 FOREIGN KEY (escalation_period) REFERENCES time_periods(timeperiod_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: escalation_tree_template_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY escalation_tree_template
    ADD CONSTRAINT escalation_tree_template_ibfk_1 FOREIGN KEY (template_id) REFERENCES escalation_templates(template_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: escalation_tree_template_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY escalation_tree_template
    ADD CONSTRAINT escalation_tree_template_ibfk_2 FOREIGN KEY (tree_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: extended_info_coords_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY extended_info_coords
    ADD CONSTRAINT extended_info_coords_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_host
    ADD CONSTRAINT external_host_ibfk_1 FOREIGN KEY (external_id) REFERENCES externals(external_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_host
    ADD CONSTRAINT external_host_ibfk_2 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_host_profile_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_host_profile
    ADD CONSTRAINT external_host_profile_ibfk_1 FOREIGN KEY (external_id) REFERENCES externals(external_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_host_profile_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_host_profile
    ADD CONSTRAINT external_host_profile_ibfk_2 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_service_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_service
    ADD CONSTRAINT external_service_ibfk_1 FOREIGN KEY (external_id) REFERENCES externals(external_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_service_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_service
    ADD CONSTRAINT external_service_ibfk_2 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_service_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_service
    ADD CONSTRAINT external_service_ibfk_3 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_service_names_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_service_names
    ADD CONSTRAINT external_service_names_ibfk_1 FOREIGN KEY (external_id) REFERENCES externals(external_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: external_service_names_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY external_service_names
    ADD CONSTRAINT external_service_names_ibfk_2 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: host_dependencies_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY host_dependencies
    ADD CONSTRAINT host_dependencies_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: host_dependencies_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY host_dependencies
    ADD CONSTRAINT host_dependencies_ibfk_2 FOREIGN KEY (parent_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: host_overrides_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY host_overrides
    ADD CONSTRAINT host_overrides_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: host_parent_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY host_parent
    ADD CONSTRAINT host_parent_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: host_parent_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY host_parent
    ADD CONSTRAINT host_parent_ibfk_2 FOREIGN KEY (parent_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: hostgroup_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hostgroup_host
    ADD CONSTRAINT hostgroup_host_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: hostgroup_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hostgroup_host
    ADD CONSTRAINT hostgroup_host_ibfk_2 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: hostgroups_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hostgroups
    ADD CONSTRAINT hostgroups_ibfk_1 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: hostgroups_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hostgroups
    ADD CONSTRAINT hostgroups_ibfk_2 FOREIGN KEY (host_escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: hostgroups_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hostgroups
    ADD CONSTRAINT hostgroups_ibfk_3 FOREIGN KEY (service_escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: hostprofile_overrides_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hostprofile_overrides
    ADD CONSTRAINT hostprofile_overrides_ibfk_1 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: hosts_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_ibfk_1 FOREIGN KEY (hostextinfo_id) REFERENCES extended_host_info_templates(hostextinfo_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: hosts_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_ibfk_2 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: hosts_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_ibfk_3 FOREIGN KEY (host_escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: hosts_ibfk_4; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY hosts
    ADD CONSTRAINT hosts_ibfk_4 FOREIGN KEY (service_escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: import_column_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_column
    ADD CONSTRAINT import_column_ibfk_1 FOREIGN KEY (schema_id) REFERENCES import_schema(schema_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_contactgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_contactgroup
    ADD CONSTRAINT import_match_contactgroup_ibfk_1 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_contactgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_contactgroup
    ADD CONSTRAINT import_match_contactgroup_ibfk_2 FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_group_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_group
    ADD CONSTRAINT import_match_group_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_group_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_group
    ADD CONSTRAINT import_match_group_ibfk_2 FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_hostgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_hostgroup
    ADD CONSTRAINT import_match_hostgroup_ibfk_1 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_hostgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_hostgroup
    ADD CONSTRAINT import_match_hostgroup_ibfk_2 FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match
    ADD CONSTRAINT import_match_ibfk_1 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match
    ADD CONSTRAINT import_match_ibfk_2 FOREIGN KEY (column_id) REFERENCES import_column(column_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match
    ADD CONSTRAINT import_match_ibfk_3 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: import_match_parent_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_parent
    ADD CONSTRAINT import_match_parent_ibfk_1 FOREIGN KEY (parent_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_parent_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_parent
    ADD CONSTRAINT import_match_parent_ibfk_2 FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_servicename_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_servicename
    ADD CONSTRAINT import_match_servicename_ibfk_1 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_servicename_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_servicename
    ADD CONSTRAINT import_match_servicename_ibfk_2 FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_serviceprofile_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_serviceprofile
    ADD CONSTRAINT import_match_serviceprofile_ibfk_1 FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_match_serviceprofile_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_match_serviceprofile
    ADD CONSTRAINT import_match_serviceprofile_ibfk_2 FOREIGN KEY (match_id) REFERENCES import_match(match_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: import_schema_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY import_schema
    ADD CONSTRAINT import_schema_ibfk_1 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_child_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_child
    ADD CONSTRAINT monarch_group_child_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_child_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_child
    ADD CONSTRAINT monarch_group_child_ibfk_2 FOREIGN KEY (child_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_host
    ADD CONSTRAINT monarch_group_host_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_host
    ADD CONSTRAINT monarch_group_host_ibfk_2 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_hostgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_hostgroup
    ADD CONSTRAINT monarch_group_hostgroup_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_hostgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_hostgroup
    ADD CONSTRAINT monarch_group_hostgroup_ibfk_2 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_macro_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_macro
    ADD CONSTRAINT monarch_group_macro_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_macro_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_macro
    ADD CONSTRAINT monarch_group_macro_ibfk_2 FOREIGN KEY (macro_id) REFERENCES monarch_macros(macro_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: monarch_group_props_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY monarch_group_props
    ADD CONSTRAINT monarch_group_props_ibfk_1 FOREIGN KEY (group_id) REFERENCES monarch_groups(group_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: profile_host_profile_service_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profile_host_profile_service
    ADD CONSTRAINT profile_host_profile_service_ibfk_1 FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: profile_host_profile_service_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profile_host_profile_service
    ADD CONSTRAINT profile_host_profile_service_ibfk_2 FOREIGN KEY (hostprofile_id) REFERENCES profiles_host(hostprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: profile_hostgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profile_hostgroup
    ADD CONSTRAINT profile_hostgroup_ibfk_1 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: profile_parent_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profile_parent
    ADD CONSTRAINT profile_parent_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: profiles_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profiles_host
    ADD CONSTRAINT profiles_host_ibfk_1 FOREIGN KEY (host_extinfo_id) REFERENCES extended_host_info_templates(hostextinfo_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: profiles_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profiles_host
    ADD CONSTRAINT profiles_host_ibfk_2 FOREIGN KEY (host_escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: profiles_host_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY profiles_host
    ADD CONSTRAINT profiles_host_ibfk_3 FOREIGN KEY (service_escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: service_dependency_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY service_dependency
    ADD CONSTRAINT service_dependency_ibfk_1 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: service_dependency_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY service_dependency
    ADD CONSTRAINT service_dependency_ibfk_2 FOREIGN KEY (depend_on_host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: service_instance_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY service_instance
    ADD CONSTRAINT service_instance_ibfk_1 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: service_names_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY service_names
    ADD CONSTRAINT service_names_ibfk_1 FOREIGN KEY (extinfo) REFERENCES extended_service_info_templates(serviceextinfo_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: service_names_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY service_names
    ADD CONSTRAINT service_names_ibfk_2 FOREIGN KEY (escalation) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: service_overrides_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY service_overrides
    ADD CONSTRAINT service_overrides_ibfk_1 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: servicegroup_service_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicegroup_service
    ADD CONSTRAINT servicegroup_service_ibfk_1 FOREIGN KEY (servicegroup_id) REFERENCES servicegroups(servicegroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: servicegroup_service_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicegroup_service
    ADD CONSTRAINT servicegroup_service_ibfk_2 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: servicegroup_service_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicegroup_service
    ADD CONSTRAINT servicegroup_service_ibfk_3 FOREIGN KEY (service_id) REFERENCES services(service_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: servicegroups_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicegroups
    ADD CONSTRAINT servicegroups_ibfk_1 FOREIGN KEY (escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: servicename_dependency_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicename_dependency
    ADD CONSTRAINT servicename_dependency_ibfk_1 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: servicename_dependency_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicename_dependency
    ADD CONSTRAINT servicename_dependency_ibfk_2 FOREIGN KEY (depend_on_host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: servicename_overrides_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY servicename_overrides
    ADD CONSTRAINT servicename_overrides_ibfk_1 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: serviceprofile_host_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY serviceprofile_host
    ADD CONSTRAINT serviceprofile_host_ibfk_1 FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: serviceprofile_host_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY serviceprofile_host
    ADD CONSTRAINT serviceprofile_host_ibfk_2 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: serviceprofile_hostgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY serviceprofile_hostgroup
    ADD CONSTRAINT serviceprofile_hostgroup_ibfk_1 FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: serviceprofile_hostgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY serviceprofile_hostgroup
    ADD CONSTRAINT serviceprofile_hostgroup_ibfk_2 FOREIGN KEY (hostgroup_id) REFERENCES hostgroups(hostgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: serviceprofile_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY serviceprofile
    ADD CONSTRAINT serviceprofile_ibfk_1 FOREIGN KEY (servicename_id) REFERENCES service_names(servicename_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: serviceprofile_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY serviceprofile
    ADD CONSTRAINT serviceprofile_ibfk_2 FOREIGN KEY (serviceprofile_id) REFERENCES profiles_service(serviceprofile_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: services_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_ibfk_1 FOREIGN KEY (host_id) REFERENCES hosts(host_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: services_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_ibfk_2 FOREIGN KEY (serviceextinfo_id) REFERENCES extended_service_info_templates(serviceextinfo_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: services_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY services
    ADD CONSTRAINT services_ibfk_3 FOREIGN KEY (escalation_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE SET NULL;


--
-- Name: time_period_exclude_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY time_period_exclude
    ADD CONSTRAINT time_period_exclude_ibfk_1 FOREIGN KEY (timeperiod_id) REFERENCES time_periods(timeperiod_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: time_period_exclude_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY time_period_exclude
    ADD CONSTRAINT time_period_exclude_ibfk_2 FOREIGN KEY (exclude_id) REFERENCES time_periods(timeperiod_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: time_period_property_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY time_period_property
    ADD CONSTRAINT time_period_property_ibfk_1 FOREIGN KEY (timeperiod_id) REFERENCES time_periods(timeperiod_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: tree_template_contactgroup_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY tree_template_contactgroup
    ADD CONSTRAINT tree_template_contactgroup_ibfk_1 FOREIGN KEY (contactgroup_id) REFERENCES contactgroups(contactgroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: tree_template_contactgroup_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY tree_template_contactgroup
    ADD CONSTRAINT tree_template_contactgroup_ibfk_2 FOREIGN KEY (template_id) REFERENCES escalation_templates(template_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: tree_template_contactgroup_ibfk_3; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY tree_template_contactgroup
    ADD CONSTRAINT tree_template_contactgroup_ibfk_3 FOREIGN KEY (tree_id) REFERENCES escalation_trees(tree_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: user_group_ibfk_1; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY user_group
    ADD CONSTRAINT user_group_ibfk_1 FOREIGN KEY (user_id) REFERENCES users(user_id) ON UPDATE RESTRICT ON DELETE CASCADE;


--
-- Name: user_group_ibfk_2; Type: FK CONSTRAINT; Schema: public; Owner: monarch
--

ALTER TABLE ONLY user_group
    ADD CONSTRAINT user_group_ibfk_2 FOREIGN KEY (usergroup_id) REFERENCES user_groups(usergroup_id) ON UPDATE RESTRICT ON DELETE CASCADE;


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

