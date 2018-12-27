--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'LATIN1';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public, pg_catalog;

--
-- Data for Name: user_groups; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY user_groups (usergroup_id, name, description) FROM stdin;
1	super_users	System defined group granted complete access.
\.


--
-- Data for Name: access_list; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY access_list (object, type, usergroup_id, access_values) FROM stdin;
commands	design_manage	1	add,modify,delete
commit	control	1	full_control
contactgroups	design_manage	1	add,modify,delete
contacts	design_manage	1	add,modify,delete
contact_templates	design_manage	1	add,modify,delete
escalations	design_manage	1	add,modify,delete
export	design_manage	1	add,modify,delete
extended_host_info_templates	design_manage	1	add,modify,delete
extended_service_info_templates	design_manage	1	add,modify,delete
externals	design_manage	1	add,modify,delete
ez_commit	ez	1	ez_commit
ez_discover	ez	1	ez_discover
ez_enabled	ez	1	ez_enabled
ez_hosts	ez	1	ez_hosts
ez_host_groups	ez	1	ez_host_groups
ez_import	ez	1	ez_import
ez_notifications	ez	1	ez_notifications
ez_profiles	ez	1	ez_profiles
ez_setup	ez	1	ez_setup
files	control	1	full_control
hostgroups	design_manage	1	add,modify,delete
hosts	design_manage	1	add,modify,delete
host_delete_tool	tools	1	add,modify,delete
host_dependencies	design_manage	1	add,modify,delete
host_templates	design_manage	1	add,modify,delete
import	discover	1	full_control
load	control	1	full_control
main_ez	ez	1	main_ez
manage	group_macro	1	manage
match_strings	discover	1	full_control
nagios_cgi_configuration	control	1	full_control
nagios_main_configuration	control	1	full_control
nagios_resource_macros	control	1	full_control
nmap	discover	1	full_control
parent_child	design_manage	1	add,modify,delete
pre_flight_test	control	1	full_control
process_stage	discover	1	full_control
profiles	design_manage	1	add,modify,delete
run_external_scripts	control	1	full_control
servicegroups	design_manage	1	add,modify,delete
services	design_manage	1	add,modify,delete
service_delete_tool	tools	1	add,modify,delete
service_dependency_templates	design_manage	1	add,modify,delete
service_templates	design_manage	1	add,modify,delete
setup	control	1	full_control
time_periods	design_manage	1	add,modify,delete
users	control	1	full_control
user_groups	control	1	full_control
\.


--
-- Data for Name: commands; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY commands (command_id, name, type, data, comment) FROM stdin;
1	check_local_load	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_load -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	# 'check_local_load' command definition
2	check_nntp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nntp -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	# 'check_nntp' command definition
3	check_telnet	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 23]]>\n </prop>\n</data>	# 'check_telnet' command definition
4	check_ftp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_ftp -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	# 'check_ftp' command definition
5	host-notify-by-email	notify	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "GroundWork Host Status Notification:\\n\\nType:        $NOTIFICATIONTYPE$\\nHost:        $HOSTNAME$ ($HOSTADDRESS$)\\nHost State:  $HOSTSTATE$\\nHost Info:   $HOSTOUTPUT$\\nTime:        $LONGDATETIME$\\nHost Notes:  `echo '$HOSTNOTES$' | sed 's/<br>/\\\\n/g'`\\n" | /usr/bin/mail -s "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$" $CONTACTEMAIL$]]>\n  </prop>\n</data>	# 'host-notify-by-email' command definition
6	process-service-perfdata	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "$LASTSERVICECHECK$\\t$HOSTNAME$\\t$SERVICEDESC$\\t$SERVICESTATE$\\t$SERVICEATTEMPT$\\t$SERVICESTATETYPE$\\t$SERVICEEXECUTIONTIME$\\t$SERVICELATENCY$\\t$SERVICEOUTPUT$\\t$SERVICEPERFDATA$\\n" >> /usr/local/nagios/var/service-perfdata.dat]]>\n </prop>\n</data>	# 'process-service-perfdata' command definition
7	check-host-alive	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_icmp -H $HOSTADDRESS$ -w 3000.0,80% -c 5000.0,100% -n 1]]>\n  </prop>\n</data>	# 'check-host-alive' command definition
8	check_udp	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_udp -H $HOSTADDRESS$ -p $ARG1$]]>\n </prop>\n</data>	# 'check_udp' command definition
9	service-notify-by-epager	notify	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "Host $HOSTNAME$ is $HOSTSTATE$\\nService $SERVICEDESC$ is $SERVICESTATE$\\nInfo: $SERVICEOUTPUT$\\nTime: $LONGDATETIME$\\n" | /usr/bin/mail -s "$NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$" $CONTACTPAGER$]]>\n  </prop>\n</data>	# 'notify-by-epager' command definition
10	check_local_procs	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_procs -w $ARG1$ -c $ARG2$ -s $ARG3$]]>\n </prop>\n</data>	# 'check_local_procs' command definition
11	check_http	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_http -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	# 'check_http' command definition
12	check_pop3	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_pop -H $HOSTADDRESS$]]>\n </prop>\n</data>	# 'check_pop' command definition
13	check_hpjd	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_hpjd -H $HOSTADDRESS$ -C public]]>\n </prop>\n</data>	# 'check_hpjd' command definition
14	service-notify-by-email	notify	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "GroundWork Service Status Notification:\\n\\nType:           $NOTIFICATIONTYPE$\\nHost:           $HOSTNAME$ ($HOSTADDRESS$)\\nHost State:     $HOSTSTATE$\\nService:        $SERVICEDESC$\\nService State:  $SERVICESTATE$\\nService Info:   $SERVICEOUTPUT$\\nTime:           $LONGDATETIME$\\nService Notes:  `echo '$SERVICENOTES$' | sed 's/<br>/\\\\n/g'`\\n" | /usr/bin/mail -s "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$" $CONTACTEMAIL$]]>\n  </prop>\n</data>	# 'notify-by-email' command definition
15	check_smtp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_smtp -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	# 'check_smtp' command definition
16	check_local_users	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_users -w $ARG1$ -c $ARG2$]]>\n </prop>\n</data>	# 'check_local_users' command definition
17	host-notify-by-epager	notify	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "Host $HOSTNAME$ is $HOSTSTATE$\\nInfo: $HOSTOUTPUT$\\nTime: $LONGDATETIME$\\n" | /usr/bin/mail -s "$NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$" $CONTACTPAGER$]]>\n  </prop>\n</data>	# 'host-notify-by-epager' command definition
18	check_proc	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_procs -c $ARG1$ -C $ARG2$]]>\n </prop>\n</data>	# 'check_procs' command definition
19	check_ping	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[$USER1$/check_icmp -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$ -n 5]]>\n </prop>\n</data>	# 'check_ping' command definition
20	check_tcp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p $ARG1$]]>\n  </prop>\n</data>	# 'check_tcp' command definition
21	check_dns	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_dns -t 30 -s $HOSTADDRESS$ -H "$ARG1$"]]>\n  </prop>\n</data>	# 'check_dns' command definition
22	check_local_disk	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_disk -m -w "$ARG1$" -c "$ARG2$" -p "$ARG3$"]]>\n  </prop>\n</data>	# 'check_local_disk' command definition
23	process-host-perfdata	check	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "$LASTHOSTCHECK$\\t$HOSTNAME$\\t$HOSTSTATE$\\t$HOSTATTEMPT$\\t$HOSTSTATETYPE$\\t$HOSTEXECUTIONTIME$\\t$HOSTOUTPUT$\\t$HOSTPERFDATA$\\n" >> /usr/local/nagios/var/host-perfdata.dat]]>\n </prop>\n</data>	# 'process-host-perfdata' command definition
24	check_alive	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_icmp -H $HOSTADDRESS$ -w 3000.0,80% -c 5000.0,100% -n 1]]>\n  </prop>\n</data>	\N
25	check_tcp_ssh	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 22]]>\n  </prop>\n</data>	\N
26	check_by_ssh_disk	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_disk -w $ARG1$ -c $ARG2$ -p $ARG3$"]]>\n  </prop>\n</data>	\N
27	check_by_ssh_load	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_load -w $ARG1$ -c $ARG2$"]]>\n  </prop>\n</data>	\N
28	check_by_ssh_mem	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_mem.pl -U -w $ARG1$ -c $ARG2$"]]>\n  </prop>\n</data>	\N
29	check_by_ssh_process_count	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -w $ARG1$ -c $ARG2$"]]>\n  </prop>\n</data>	\N
30	check_by_ssh_swap	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_swap -w $ARG1$ -c $ARG2$"]]>\n  </prop>\n</data>	\N
31	check_snmp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -o "$ARG1$" -r "$ARG2$" -l "$ARG3$" -C '$USER7$']]>\n  </prop>\n</data>	\N
32	check_snmp_if	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -C '$USER7$' -o "IF-MIB::ifInOctets.$ARG1$,IF-MIB::ifOutOctets.$ARG1$ ,IF-MIB::ifInDiscards.$ARG1$,IF-MIB::ifOutDiscards.$ARG1$,IF-MIB::ifInErrors.$ARG1$,IF-MIB::ifOutErrors.$ARG1$"]]>\n  </prop>\n</data>	\N
33	check_snmp_bandwidth	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -C '$USER7$' -o "IF-MIB::ifInOctets.$ARG1$,IF-MIB::ifOutOctets.$ARG1$,IF-MIB::ifSpeed.$ARG1$"]]>\n  </prop>\n</data>	\N
34	check_ifoperstatus	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_ifoperstatus -k "$ARG1$" -H $HOSTADDRESS$ -C "$USER7$"]]>\n  </prop>\n</data>	\N
35	host-notify-by-sendemail	notify	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "<html>\\n<table width='auto' style='background-color: #E6DBC3"\\;" min-width: 350px'>\\n<caption style='font-weight: bold"\\;" background-color: #B39962'><b>GroundWork Host<br>$NOTIFICATIONTYPE$ Notification</b></caption>\\n<tr>\\n<td style='background-color: #CCB98F'>Host:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host State:</td>\\n<td style='background-color: #F3EDE1'><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host Info:</td>\\n<td><b>$HOSTOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host Notes:</td>\\n<td><b>`echo '$HOSTNOTES$' | sed 's/<br>/\\\\n/g'`</b></td>\\n</tr>\\n</table>\\n</html>\\n" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$"]]>\n </prop>\n</data>	\N
36	service-notify-by-sendemail	notify	<?xml version="1.0" ?>\n<data>\n <prop name="command_line"><![CDATA[/usr/bin/printf "%b" "<html>\\n<table width='auto' style='background-color: #E6DBC3"\\;" min-width: 350px'>\\n<caption style='font-weight: bold"\\;" background-color: #B39962'>GroundWork Service<br>$NOTIFICATIONTYPE$ Notification</caption>\\n<tr>\\n<td style='background-color: #CCB98F'>Host:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Host State:</td>\\n<td><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service:</td>\\n<td><b><a href='http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$&service=$SERVICEDESC$'>$SERVICEDESC$</a></b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service State:</td>\\n<td style='background-color: #F3EDE1'><b>$SERVICESTATE$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service Info:</td>\\n<td><b>$SERVICEOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style='background-color: #CCB98F'>Service Notes:</td>\\n<td><b>`echo '$SERVICENOTES$' | sed 's/<br>/\\\\n/g'`</b></td>\\n</tr>\\n</table>\\n</html>\\n" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u "[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$"]]>\n </prop>\n</data>	\N
37	check_mysql	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_mysql -H $HOSTADDRESS$ -d "$ARG1$" -u "$ARG2$" -p "$USER6$"]]>\n  </prop>\n</data>	\N
38	check_mysql_engine	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_mysql -H $HOSTADDRESS$ -u "$ARG1$" -p "$ARG2$"]]>\n  </prop>\n</data>	\N
39	check_mysql_engine_nopw	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_mysql -H $HOSTADDRESS$ -u "$ARG1$"]]>\n  </prop>\n</data>	\N
40	check_local_procs_string	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_procs -w "$ARG1$" -c "$ARG2$" -a "$ARG3$"]]>\n  </prop>\n</data>	\N
41	check_local_mem	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_mem.pl -U -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
42	check_tcp_nsca	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$ -p 5667]]>\n  </prop>\n</data>	\N
43	check_nagios	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nagios -F /usr/local/nagios/var/status.dat -e 5 -C bin/.nagios.bin]]>\n  </prop>\n</data>	\N
44	check_nagios_latency	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nagios_latency.pl]]>\n  </prop>\n</data>	\N
45	check_local_procs_arg	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_procs -w "$ARG1$" -c "$ARG2$" -a "$ARG3$"]]>\n  </prop>\n</data>	\N
46	check_local_swap	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_swap -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
47	check_tcp_dns	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 53]]>\n  </prop>\n</data>	\N
48	check_udp_dns	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_udp -H $HOSTADDRESS$ -p 53 -s "4500 003d 668f 4000 4011 4ce9 c0a8 02f0"]]>\n  </prop>\n</data>	\N
49	check_dns_expect	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_dns -t 30 -s $HOSTADDRESS$ -H "$ARG1$" -a "$ARG2$"]]>\n  </prop>\n</data>	\N
50	check_tcp_ftp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 21]]>\n  </prop>\n</data>	\N
51	check_tcp_https	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 443]]>\n  </prop>\n</data>	\N
52	check_https	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_http -t 60 -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -S]]>\n  </prop>\n</data>	\N
53	check_tcp_port	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p "$ARG1$"]]>\n  </prop>\n</data>	\N
54	check_http_port	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_http -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -p "$ARG3$"]]>\n  </prop>\n</data>	\N
55	check_tcp_imaps	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 993]]>\n  </prop>\n</data>	\N
56	check_imaps	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_imap -t 60 -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -p 993 -S]]>\n  </prop>\n</data>	\N
57	check_tcp_nntps	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 563]]>\n  </prop>\n</data>	\N
58	check_nntps	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nntp -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -p 563 -S]]>\n  </prop>\n</data>	\N
59	check_tcp_nrpe	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 5666]]>\n  </prop>\n</data>	\N
60	check_nrpe	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$]]>\n  </prop>\n</data>	\N
61	check_tcp_pop3s	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 995]]>\n  </prop>\n</data>	\N
62	check_pop3s	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_pop -t 60 -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -S]]>\n  </prop>\n</data>	\N
63	check_tcp_smtp	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 25]]>\n  </prop>\n</data>	\N
64	check_nrpe_print_queue	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_printqueue -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
65	check_nrpe_cpu	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_cpu -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
66	check_nrpe_disk	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_disk -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
67	check_nrpe_disk_transfers	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_disktransfers -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
68	check_nrpe_exchange_mailbox_receiveq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_mbox_recvq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
69	check_nrpe_exchange_mailbox_sendq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_mbox_sendq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
70	check_nrpe_exchange_mta_workq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_mta_workq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
71	check_nrpe_exchange_public_receiveq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_pub_recvq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
72	check_nrpe_exchange_public_sendq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_pub_sendq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
73	check_nrpe_iis_bytes_received	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_bytes_received -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
74	check_nrpe_iis_bytes_sent	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_bytes_sent -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
75	check_nrpe_iis_bytes_total	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_bytes_total -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
76	check_nrpe_iis_current_connections	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_currentconnections -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
77	check_nrpe_iis_current_nonanonymous_users	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_curnonanonusers -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
78	check_nrpe_iis_get_requests	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_get_requests -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
79	check_nrpe_iis_maximum_connections	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_maximumconnections -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
80	check_nrpe_iis_post_requests	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_post_requests -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
81	check_nrpe_iis_private_bytes	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_privatebytes -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
82	check_nrpe_iis_total_not_found_errors	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_totalnotfounderrors -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
83	check_nrpe_local_cpu	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_cpu -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
84	check_nrpe_local_disk	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_disk -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
85	check_nrpe_local_memory	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mem -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
86	check_nrpe_local_pagefile	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c check_pagefile_counter -a "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
87	check_nrpe_mem	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mem -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
88	check_nrpe_mssql_buffer_cache_hits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_buf_cache_hit -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
89	check_nrpe_mssql_deadlocks	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_deadlocks -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
90	check_nrpe_mssql_full_scans	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_fullscans -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
92	check_nrpe_mssql_lock_wait_time	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_lock_wait_time -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
93	check_nrpe_mssql_lock_waits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_lock_waits -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
94	check_nrpe_mssql_log_growths	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_log_growth -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
95	check_nrpe_mssql_log_used	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_log_used -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
96	check_nrpe_mssql_memory_grants_pending	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_memgrantspending -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
97	check_nrpe_memory_pages	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_swapping -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
98	check_nrpe_mssql_transactions	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_transactions -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
99	check_nrpe_mssql_users	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_users -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
148	check_apache	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_apache.pl -H $HOSTADDRESS$]]>\n  </prop>\n</data>	\N
149	check_nt_cpuload	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v CPULOAD -l "$ARG1$"]]>\n  </prop>\n</data>	\N
150	check_nt_useddiskspace	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v USEDDISKSPACE -l $ARG1$ -w $ARG2$ -c $ARG3$]]>\n  </prop>\n</data>	\N
151	check_nt_counter_exchange_mailrq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\MSExchangeIS Mailbox(_Total)\\\\Receive Queue Size","Receive Queue Size is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
152	check_nt_counter_exchange_mailsq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\MSExchangeIS Mailbox(_Total)\\\\Send Queue Size","Send Queue Size is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
153	check_nt_counter_exchange_mtawq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\MSExchangeMTA\\\\Work Queue Length","Work Queue Length is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
154	check_nt_counter_exchange_publicrq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\MSExchangeIS Public(_Total)\\\\Receive Queue Size","Receive Queue Size is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
155	check_nt_counter_exchange_publicsq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\MSExchangeIS Public(_Total)\\\\Send Queue Size","Send Queue Size is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
156	check_nt_memuse	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v MEMUSE -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
157	check_udp_nsclient	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_udp -H $HOSTADDRESS$ -p $USER19$]]>\n  </prop>\n</data>	\N
158	check_ldap	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_ldap -t 60  -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -b "$ARG3$" -3]]>\n  </prop>\n</data>	\N
159	check_tcp_ldap	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -t 60 -H $HOSTADDRESS$ -w 2 -c 4 -p 389]]>\n  </prop>\n</data>	\N
160	check_snmptraps	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_snmptraps.pl $HOSTNAME$ $ARG1$ $ARG2$ $ARG3$]]>\n  </prop>\n</data>	\N
161	check_ssh	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_ssh -H $HOSTADDRESS$ -t 60]]>\n  </prop>\n</data>	\N
162	check_by_ssh_apache	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_apache.pl -H $HOSTADDRESS$"]]>\n  </prop>\n</data>	\N
164	check_by_ssh_process_proftpd	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -c 1:1 -a proftpd:\\ \\(accepting"]]>\n  </prop>\n</data>	\N
165	check_by_ssh_process_slapd	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -w $ARG1$ -c $ARG2$ -C slapd"]]>\n  </prop>\n</data>	\N
166	check_by_ssh_mysql	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_mysql -H $HOSTADDRESS$ -d $ARG1$ -u $ARG2$ -p $ARG3$"]]>\n  </prop>\n</data>	\N
167	check_by_ssh_mysql_engine	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_mysql -H $HOSTADDRESS$ -u $ARG1$ -p $ARG2$"]]>\n  </prop>\n</data>	\N
168	check_by_ssh_process_args	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -w $ARG1$ -c $ARG2$ -a $ARG3$"]]>\n  </prop>\n</data>	\N
169	check_sendmail	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_smtp -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -C "ehlo groundworkopensource.com" -R "ENHANCEDSTATUSCODES" -f nagios@$HOSTADDRESS$]]>\n  </prop>\n</data>	\N
170	check_by_ssh_mailq_sendmail	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "sudo $USER22$/check_mailq -w $ARG1$ -c $ARG2$ -M sendmail"]]>\n  </prop>\n</data>	\N
171	check_by_ssh_process_crond	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -c 1:1 -a crond"]]>\n  </prop>\n</data>	\N
172	check_by_ssh_process_sendmail_accept	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -c 1:1 -a sendmail:\\ accepting\\ con"]]>\n  </prop>\n</data>	\N
173	check_by_ssh_process_sendmail_qrunner	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -c 1:1 -a sendmail:\\ Queue\\ runner"]]>\n  </prop>\n</data>	\N
174	check_by_ssh_process_xinetd	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -c 1:1 -a xinetd"]]>\n  </prop>\n</data>	\N
175	check_by_ssh_process_cmd	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -w $ARG1$ -c $ARG2$ -C $ARG3$"]]>\n  </prop>\n</data>	\N
176	check_wmi_cpu	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H "$USER21$" -c get_cpu -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
177	check_wmi_disk	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_disk -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
178	check_wmi_mem	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mem -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
179	check_wmi_exchange_mailbox_receiveq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_mbox_recvq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
180	check_wmi_exchange_mailbox_sendq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_mbox_sendq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
181	check_wmi_service	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -H $USER21$ -t 60 -c get_service -a "$HOSTADDRESS$" "$ARG1$"]]>\n  </prop>\n</data>	\N
182	check_wmi_exchange_mta_workq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_mta_workq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
183	check_wmi_exchange_public_receiveq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_pub_recvq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
184	check_wmi_exchange_public_sendq	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_pub_sendq -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
185	check_wmi_iis_bytes_received	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_bytes_received -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
186	check_wmi_iis_bytes_sent	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_bytes_sent -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
187	check_wmi_iis_bytes_total	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_bytes_total -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
188	check_wmi_iis_current_connections	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_currentconnections -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
189	check_wmi_iis_current_nonanonymous_users	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_curnonanonusers -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
190	check_wmi_iis_get_requests	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_get_requests -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
191	check_wmi_iis_maximum_connections	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_maximumconnections -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
192	check_wmi_iis_post_requests	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_post_requests -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
193	check_wmi_iis_private_bytes	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_privatebytes -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
194	check_wmi_iis_total_not_found_errors	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_totalnotfounderrors -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
225	check_citrix	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_ica_master_browser.pl -I $HOSTADDRESS$ -P $HOSTADDRESS$]]>\n  </prop>\n</data>	\N
226	check_wmi_mssql_buffer_cache_hits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_buf_cache_hit -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
227	check_wmi_mssql_deadlocks	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_deadlocks -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
228	check_wmi_disk_transfers	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_disktransfers -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
229	check_wmi_mssql_full_scans	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_fullscans -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
231	check_wmi_mssql_lock_wait_time	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_lock_wait_time -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
232	check_wmi_mssql_lock_waits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_lock_waits -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
233	check_wmi_mssql_log_growths	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_log_growth -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
234	check_wmi_mssql_log_used	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_log_used -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
235	check_wmi_mssql_memory_grants_pending	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_memgrantspending -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
236	check_wmi_memory_pages	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_swapping -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
237	check_wmi_mssql_transactions	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_transactions -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$" "$ARG3$"]]>\n  </prop>\n</data>	\N
238	check_wmi_mssql_users	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_users -a "$HOSTADDRESS$" "$ARG1$" "$ARG2$"]]>\n  </prop>\n</data>	\N
246	check_nt_counter_disktransfers	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\PhysicalDisk(_Total)\\\\Disk Transfers/sec","PhysicalDisk(_Total) Disk Transfers/sec is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
247	check_nt_counter_memory_pages	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\Memory\\\\Pages/sec","Pages per Sec is %.f" -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
248	check_nt_counter_mssql_bufcache_hits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Buffer Manager\\\\Buffer cache hit ratio","SQLServer:Buffer Manager Buffer cache hit ratio is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
249	check_nt_counter_mssql_deadlocks	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Locks(_Total)\\\\Number of Deadlocks/sec","SQLServer:Locks(_Total) Number of Deadlocks/sec is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
250	check_nt_counter_mssql_latch_waits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Latches\\\\Latch Waits/sec","SQLServer:Latches Latch Waits/sec is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
251	check_nt_counter_mssql_lock_wait_time	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Locks(_Total)\\\\Lock Wait Time (ms)","SQLServer:Locks(_Total) Lock Wait Time (ms) is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
252	check_nt_counter_mssql_lock_waits	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Locks(_Total)\\\\Lock Waits/sec","SQLServer:Locks(_Total) Lock Waits/sec is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
253	check_nt_counter_mssql_log_growths	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Databases(_Total)\\\\Log Growths","SQLServer:Databases(_Total) Log Growths is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
254	check_nt_counter_mssql_log_used	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Databases(_Total)\\\\Percent Log Used","SQLServer:Databases(_Total) Percent Log Used is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
255	check_nt_counter_mssql_memory_grants_pending	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Memory Manager\\\\Memory Grants Pending","SQLServer:Memory Manager Memory Grants Pending is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
256	check_nt_counter_mssql_transactions	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\SQLServer:Databases(_Total)\\\\Transactions/sec","SQLServer:Databases(_Total) Transactions/sec is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
257	check_nt_counter_network_interface	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l "\\\\Network Interface(MS TCP Loopback interface)\\\\Bytes Total/sec","Network Interface(MS TCP Loopback interface) Bytes Total/sec is %.f " -w "$ARG1$" -c "$ARG2$"]]>\n  </prop>\n</data>	\N
258	check_by_ssh_process_named	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procs -c 1:1 -C named -a /etc/named.conf"]]>\n  </prop>\n</data>	\N
259	check_syslog	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_syslog_gw.pl -l $ARG1$ -s /tmp/$HOSTNAME$.tmp -x $ARG2$ -a $HOSTADDRESS$]]>\n  </prop>\n</data>	\N
260	check_imap	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_imap -t 60 -H $HOSTADDRESS$ -w "$ARG1$" -c "$ARG2$" -p 143]]>\n  </prop>\n</data>	\N
263	check_snmp_alive	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -o .1.3.6.1.2.1.1.3.0 -l "Uptime is " -C '$USER7$']]>\n  </prop>\n</data>	\N
264	check_nt	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nt -p $USER19$ -s $USER4$ -H $HOSTADDRESS$ -v CLIENTVERSION]]>\n  </prop>\n</data>	\N
265	check_nrpe_service	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_nrpe -H $HOSTADDRESS$ -t 60 -c get_service -a "$HOSTADDRESS$" "$ARG1$"]]>\n  </prop>\n</data>	\N
267	check_local_proc_cpu	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_procl.sh --cpu -w "$ARG1$" -c "$ARG2$" -p "$ARG3$"]]>\n  </prop>\n</data>	\N
268	check_local_proc_mem	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_procl.sh --mem -w "$ARG1$" -c "$ARG2$" -p "$ARG3$"]]>\n  </prop>\n</data>	\N
269	check_dir_size	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_dir_size.sh $ARG1$ $ARG2$ $ARG3$]]>\n  </prop>\n</data>	\N
270	check_tcp_gw_listener	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$ -p 4913]]>\n  </prop>\n</data>	\N
271	launch_perfdata_process	other	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/local/groundwork/nagiosfeeders/bin/launch_perf_data_processing]]>\n  </prop>\n</data>	\N
272	check_by_ssh_cpu_proc	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procl.sh --cpu -w $ARG1$ -c $ARG2$ -p $ARG3$"]]>\n  </prop>\n</data>	\N
273	check_by_ssh_mem_proc	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER22$/check_procl.sh --mem -w $ARG1$ -c $ARG2$ -p $ARG3$"]]>\n  </prop>\n</data>	\N
274	check_by_ssh_nagios_latency	check	<?xml version="1.0" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l "$USER17$" -C "$USER1$/check_nagios_latency.pl"]]>\n  </prop>\n</data>	\N
275	check_msg	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_dummy $ARG1$ $ARG2$]]>\n  </prop>\n</data>	\N
276	check_gdma_fresh	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_dummy 1 $ARG1$]]>\n  </prop>\n</data>	\N
277	check_grafana	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_grafana.pl]]>\n  </prop>\n</data>	\N
278	check_influxdb	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_influxdb.pl]]>\n  </prop>\n</data>	\N
279	host-notify-by-noma	notify	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/local/groundwork/noma/notifier/alert_via_noma.pl -c h -s "$HOSTSTATE$" -H "$HOSTNAME$" -G "$HOSTGROUPNAMES$" -n "$NOTIFICATIONTYPE$" -i "$HOSTADDRESS$" -o "$HOSTOUTPUT$" -t "$TIMET$" -u "$$(( $HOSTPROBLEMID$ ? $HOSTPROBLEMID$ : $LASTHOSTPROBLEMID$ ))" -A "$$([ -n "$NOTIFICATIONAUTHORALIAS$" ] && echo "$NOTIFICATIONAUTHORALIAS$" || echo "$NOTIFICATIONAUTHOR$")" -C "$NOTIFICATIONCOMMENT$" -R "$NOTIFICATIONRECIPIENTS$"]]>\n  </prop>\n</data>	# 'host-notify-by-noma' command definition
280	service-notify-by-noma	notify	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[/usr/local/groundwork/noma/notifier/alert_via_noma.pl -c s -s "$SERVICESTATE$" -H "$HOSTNAME$" -G "$HOSTGROUPNAMES$" -E "$SERVICEGROUPNAMES$" -S "$SERVICEDESC$" -o "$SERVICEOUTPUT$" -n "$NOTIFICATIONTYPE$" -a "$HOSTALIAS$" -i "$HOSTADDRESS$" -t "$TIMET$" -u "$$(( $SERVICEPROBLEMID$ ? $SERVICEPROBLEMID$ : $LASTSERVICEPROBLEMID$ ))" -A "$$([ -n "$NOTIFICATIONAUTHORALIAS$" ] && echo "$NOTIFICATIONAUTHORALIAS$" || echo "$NOTIFICATIONAUTHOR$")" -C "$NOTIFICATIONCOMMENT$" -R "$NOTIFICATIONRECIPIENTS$"]]>\n  </prop>\n</data>	# 'service-notify-by-noma' command definition
281	check_wmi_plus_cpu	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checkcpu  -w $ARG1$ -c $ARG2$]]>\n  </prop>\n</data>	\N
282	check_wmi_plus_cpuq	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checkcpuq  -w $ARG1$ -c $ARG2$]]>\n  </prop>\n</data>	\N
283	check_wmi_plus_disk	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checkdrivesize -a $ARG1$  -w $ARG2$ -c $ARG3$]]>\n  </prop>\n</data>	\N
284	check_wmi_plus_eventlog	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checkeventlog -a $ARG1$ -o $ARG2$ -3 $ARG3$  -w $ARG4$ -c $ARG5$]]>\n  </prop>\n</data>	\N
285	check_wmi_plus_mem	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checkmem  -w $ARG1$ -c $ARG2$]]>\n  </prop>\n</data>	\N
286	check_wmi_plus_net	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checknetwork -a $ARG1$  -w $ARG2$ -c $ARG3$]]>\n  </prop>\n</data>	\N
287	check_wmi_plus_time	check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="command_line"><![CDATA[$USER1$/check_wmi_plus.pl -H $HOSTADDRESS$  -A $USER9$ -m checktime -w $ARG1$ -c $ARG2$]]>\n  </prop>\n</data>	\N
\.


--
-- Name: commands_command_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('commands_command_id_seq', 287, true);


--
-- Data for Name: contact_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_templates (contacttemplate_id, name, host_notification_period, service_notification_period, data, comment) FROM stdin;
1	generic-contact-1	1	1	<?xml version="1.0" ?>\n<data>\n  <prop name="host_notification_options"><![CDATA[d,r]]>\n  </prop>\n  <prop name="service_notification_options"><![CDATA[c,r]]>\n  </prop>\n </data>	\N
2	generic-contact-2	3	3	<?xml version="1.0" ?>\n<data>\n <prop name="host_notification_options"><![CDATA[d,u,r]]>\n </prop>\n <prop name="service_notification_options"><![CDATA[u,c,w,r]]>\n </prop>\n</data>	\N
\.


--
-- Data for Name: contact_command; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_command (contacttemplate_id, type, command_id) FROM stdin;
1	host	5
2	host	5
2	service	9
1	service	14
2	service	14
2	host	17
\.


--
-- Data for Name: contacts; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contacts (contact_id, name, alias, email, pager, contacttemplate_id, status, comment) FROM stdin;
1	jdoe	John Doe	jdoe@localhost	\N	1	1	# 'jdoe' contact definition
2	nagiosadmin	Nagios Admin	nagios-admin@localhost	pagenagios-admin@localhost	2	1	# 'nagios' contact definition
\.


--
-- Data for Name: contact_command_overrides; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_command_overrides (contact_id, type, command_id) FROM stdin;
\.


--
-- Data for Name: monarch_groups; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_groups (group_id, name, description, location, status, data) FROM stdin;
1	windows-gdma-2.1	Group for configuration of Windows GDMA systems	/usr/local/groundwork/monarch/htdocs/gdma	\N	<?xml version="1.0" ?>\n<data>\n <prop name="label_enabled"><![CDATA[]]>\n </prop>\n <prop name="label"><![CDATA[]]>\n </prop>\n <prop name="nagios_etc"><![CDATA[]]>\n </prop>\n <prop name="use_hosts"><![CDATA[]]>\n </prop>\n <prop name="inherit_host_active_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_host_passive_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_service_active_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_service_passive_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="host_active_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="host_passive_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="service_active_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="service_passive_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n</data>
2	unix-gdma-2.1	Group for configuration of Linux and Solaris GDMA systems	/usr/local/groundwork/monarch/htdocs/gdma	\N	<?xml version="1.0" ?>\n<data>\n <prop name="label_enabled"><![CDATA[]]>\n </prop>\n <prop name="label"><![CDATA[]]>\n </prop>\n <prop name="nagios_etc"><![CDATA[]]>\n </prop>\n <prop name="use_hosts"><![CDATA[]]>\n </prop>\n <prop name="inherit_host_active_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_host_passive_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_service_active_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_service_passive_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="host_active_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="host_passive_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="service_active_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="service_passive_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n</data>
3	auto-registration	Group for management of auto-registered GDMA systems.  See the default_monarch_group in config/register_agent.properties for details.	/usr/local/groundwork/monarch/htdocs/gdma	\N	<?xml version="1.0" ?>\n<data>\n <prop name="label_enabled"><![CDATA[]]>\n </prop>\n <prop name="label"><![CDATA[]]>\n </prop>\n <prop name="nagios_etc"><![CDATA[]]>\n </prop>\n <prop name="use_hosts"><![CDATA[]]>\n </prop>\n <prop name="inherit_host_active_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_host_passive_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_service_active_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="inherit_service_passive_checks_enabled"><![CDATA[1]]>\n </prop>\n <prop name="host_active_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="host_passive_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="service_active_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n <prop name="service_passive_checks_enabled"><![CDATA[-zero-]]>\n </prop>\n</data>
\.


--
-- Data for Name: contact_group; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_group (contact_id, group_id) FROM stdin;
\.


--
-- Data for Name: escalation_trees; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY escalation_trees (tree_id, name, description, type) FROM stdin;
\.


--
-- Data for Name: extended_host_info_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY extended_host_info_templates (hostextinfo_id, name, data, script, comment) FROM stdin;
\.


--
-- Data for Name: profiles_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY profiles_host (hostprofile_id, name, description, host_template_id, host_extinfo_id, host_escalation_id, service_escalation_id, data) FROM stdin;
1	host-profile-service-ping	Host profile for ping	1	\N	\N	\N	\N
2	host-profile-snmp-network	Host Profile for monitoring network devices using snmp	1	\N	\N	\N	\N
3	host-profile-ssh-unix	Host Profile for monitoring servers using ssh	1	\N	\N	\N	<?xml version="1.0" ?>\n<data>\n  <prop name="hosts_select"><![CDATA[checked]]>\n  </prop>\n  <prop name="apply_services"><![CDATA[replace]]>\n  </prop>\n</data>
4	host-profile-cacti-host	Cacti host profile	1	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
5	gdma-aix-host	GDMA-monitored AIX host	2	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
6	gdma-linux-host	GDMA-monitored Linux host	3	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
7	gdma-solaris-host	GDMA-monitored Solaris host	4	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
8	gdma-windows-host	GDMA-monitored Windows host	5	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
\.


--
-- Data for Name: hosts; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY hosts (host_id, name, alias, address, os, hosttemplate_id, hostextinfo_id, hostprofile_id, host_escalation_id, service_escalation_id, status, comment, notes) FROM stdin;
1	localhost	Linux Server #1	127.0.0.1	n/a	1	\N	\N	\N	\N	1	# 'linux1' host definition	\N
\.


--
-- Data for Name: contact_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_host (contact_id, host_id) FROM stdin;
1	1
\.


--
-- Data for Name: contact_host_profile; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_host_profile (contact_id, hostprofile_id) FROM stdin;
\.


--
-- Data for Name: host_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY host_templates (hosttemplate_id, name, check_period, notification_period, check_command, event_handler, data, comment) FROM stdin;
1	generic-host	3	3	7	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[3]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="obsess_over_host"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="check_interval"><![CDATA[10]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[60]]>\n  </prop>\n </data>	# Generic host definition template
2	gdma-aix-host	3	3	7	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[3]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="obsess_over_host"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[15]]>\n  </prop>\n</data>	# host_templates gdma-aix-host
3	gdma-linux-host	3	3	7	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[3]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="obsess_over_host"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[15]]>\n  </prop>\n</data>	# host_templates gdma-linux-host
4	gdma-solaris-host	3	3	7	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[3]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="obsess_over_host"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[15]]>\n  </prop>\n</data>	# host_templates gdma-solaris-host
5	gdma-windows-host	3	3	7	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[3]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="obsess_over_host"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[15]]>\n  </prop>\n</data>	# host_templates gdma-windows-host
\.


--
-- Data for Name: contact_host_template; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_host_template (contact_id, hosttemplate_id) FROM stdin;
1	1
\.


--
-- Data for Name: hostgroups; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY hostgroups (hostgroup_id, name, alias, hostprofile_id, host_escalation_id, service_escalation_id, status, comment, notes) FROM stdin;
1	Linux Servers	Linux Servers	\N	\N	\N	1	# 'linux-boxes' host group definition	\N
2	Auto-Registration	Auto-registered hosts	\N	\N	\N	\N	# hostgroup	This hostgroup is used for GDMA auto-registration.
\.


--
-- Data for Name: contact_hostgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_hostgroup (contact_id, hostgroup_id) FROM stdin;
\.


--
-- Data for Name: contact_overrides; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_overrides (contact_id, host_notification_period, service_notification_period, data) FROM stdin;
1	\N	\N	<?xml version="1.0" ?>\n<data>\n  <prop name="host_notification_options"><![CDATA[d,r]]>\n  </prop>\n  <prop name="service_notification_options"><![CDATA[c,r]]>\n  </prop>\n</data>
2	\N	\N	<?xml version="1.0" ?>\n<data>\n  <prop name="host_notification_options"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name="service_notification_options"><![CDATA[u,c,w,r]]>\n  </prop>\n</data>
\.


--
-- Data for Name: extended_service_info_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY extended_service_info_templates (serviceextinfo_id, name, data, script, comment) FROM stdin;
1	number_graph	<?xml version="1.0" ?>\n<data>\n  <prop name="notes_url"><![CDATA[/graphs/cgi-bin/label_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name="icon_image"><![CDATA[services.gif]]>\n  </prop>\n  <prop name="icon_image_alt"><![CDATA[Service Detail]]>\n  </prop>\n</data>	\N	\N
2	unix_load_graph	<?xml version="1.0" ?>\n<data>\n  <prop name="notes_url"><![CDATA[/graphs/cgi-bin/label_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name="icon_image"><![CDATA[services.gif]]>\n  </prop>\n  <prop name="icon_image_alt"><![CDATA[Service Detail]]>\n  </prop>\n</data>	\N	\N
3	percent_graph	<?xml version="1.0" ?>\n<data>\n  <prop name="notes_url"><![CDATA[/graphs/cgi-bin/label_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name="icon_image"><![CDATA[services.gif]]>\n  </prop>\n  <prop name="icon_image_alt"><![CDATA[Service Detail]]>\n  </prop>\n</data>	\N	\N
4	snmp_if	<?xml version="1.0" ?>\n<data>\n  <prop name="notes_url"><![CDATA[/graphs/cgi-bin/percent_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name="icon_image"><![CDATA[services.gif]]>\n  </prop>\n  <prop name="icon_image_alt"><![CDATA[Service Detail]]>\n  </prop>\n</data>	\N	\N
5	snmp_ifbandwidth	<?xml version="1.0" ?>\n<data>\n  <prop name="notes_url"><![CDATA[/graphs/cgi-bin/percent_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name="icon_image"><![CDATA[services.gif]]>\n  </prop>\n  <prop name="icon_image_alt"><![CDATA[Service Detail]]>\n  </prop>\n</data>	\N	\N
\.


--
-- Data for Name: services; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY services (service_id, host_id, servicename_id, servicetemplate_id, serviceextinfo_id, escalation_id, status, check_command, command_line, comment, notes, externals_arguments, inherit_ext_args) FROM stdin;
159	1	170	1	\N	\N	1	22	check_local_disk!15%!10%!/	\N	\N	\N	1
161	1	206	1	\N	\N	1	268	check_local_proc_mem!20!30!syslog-ng	\N	\N	\N	1
162	1	188	1	\N	\N	1	42	check_tcp_nsca!5!9	\N	\N	\N	1
163	1	193	1	\N	\N	1	267	check_local_proc_cpu!40!50!nagios	\N	\N	\N	1
164	1	17	1	1	\N	1	11	check_http!3!5	\N	\N	\N	1
165	1	200	1	\N	\N	1	268	check_local_proc_mem!40!50!java	\N	\N	\N	1
167	1	179	1	\N	\N	1	45	check_local_procs_arg!1:3!1:3!groundwork/foundation/container/jpp/standalone	\N	\N	\N	1
168	1	186	1	\N	\N	1	270	check_tcp_gw_listener!5!9	\N	\N	\N	1
169	1	190	1	\N	\N	1	267	check_local_proc_cpu!40!50!httpd	\N	\N	\N	1
170	1	182	1	\N	\N	1	43	\N	\N	\N	\N	1
171	1	194	1	\N	\N	1	267	check_local_proc_cpu!40!50!perl	\N	\N	\N	1
173	1	202	1	\N	\N	1	268	check_local_proc_mem!20!30!nagios	\N	\N	\N	1
175	1	191	1	\N	\N	1	267	check_local_proc_cpu!40!50!java	\N	\N	\N	1
177	1	232	1	3	\N	1	46	check_local_swap!20%!10%	\N	\N	\N	1
178	1	178	1	\N	\N	1	44	\N	\N	\N	\N	1
179	1	189	1	\N	\N	1	16	check_local_users!5!20	\N	\N	\N	1
182	1	174	1	\N	\N	1	41	check_local_mem!95!99	\N	\N	\N	1
183	1	197	1	\N	\N	1	267	check_local_proc_cpu!40!50!syslog-ng	\N	\N	\N	1
184	1	203	1	\N	\N	1	268	check_local_proc_mem!20!30!perl	\N	\N	\N	1
187	1	199	1	\N	\N	1	268	check_local_proc_mem!20!30!httpd	\N	\N	\N	1
189	1	173	1	\N	\N	1	1	check_local_load!5,4,3!10,8,6	\N	\N	\N	1
\.


--
-- Data for Name: contact_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_service (contact_id, service_id) FROM stdin;
\.


--
-- Data for Name: service_names; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY service_names (servicename_id, name, description, template, check_command, command_line, escalation, extinfo, data, externals_arguments) FROM stdin;
1	*	special use	\N	\N	\N	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
4	icmp_ping	PING	1	19	check_ping!100.0,20%!500.0,60%	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
6	icmp_ping_alive	Ping host to see if it is Alive	1	24	\N	\N	1	<?xml version="1.0" ?>\n<data>\n</data>	\N
13	udp_snmp	gwsn-snmp	1	263	\N	\N	1	<?xml version="1.0" ?>\n<data>\n</data>	\N
14	snmp_if_1	gwsn-snmp_if	1	32	check_snmp_if!1	\N	5	<?xml version="1.0" ?>\n<data>\n</data>	\N
15	snmp_ifbandwidth_1	SNMP_if_bandwidth	1	33	check_snmp_bandwidth!1	\N	5	<?xml version="1.0" ?>\n<data>\n</data>	\N
16	snmp_ifoperstatus_1	SNMP_ifoperstatus	1	34	check_ifoperstatus!1	\N	5	<?xml version="1.0" ?>\n<data>\n</data>	\N
17	tcp_http	check http server at host	1	11	check_http!3!5	\N	1	<?xml version="1.0" ?>\n<data>\n</data>	\N
20	local_mysql_engine	gwsn-local_mysql_engine	1	38	check_mysql_engine!root!d3v3l0p3r	\N	1	<?xml version="1.0" ?>\n<data>\n</data>	\N
64	nrpe_disk	check disk on nrpe server	1	66	check_nrpe_disk!*!80,90	\N	3	<?xml version="1.0" ?>\n<data>\n</data>	\N
169	tcp_ssh	Check SSH server running at host	1	161	\N	\N	1	<?xml version="1.0" ?>\n<data>\n</data>	\N
170	local_disk_root	gwsn-local_disk_root	1	22	check_local_disk!15%!10%!/	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
173	local_load	Check the local load on this unix server	1	1	check_local_load!5,4,3!10,8,6	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
174	local_memory	gwsn-local_mem	1	41	check_local_mem!95!99	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
175	local_mysql_cpu	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!mysql	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
176	local_mysql_database	gwsn-local_mysql_database	1	37	check_mysql!monarch!monarch	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
177	local_mysql_mem	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!mysql	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
178	local_nagios_latency	Check NSCA port at host	1	44	\N	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
179	local_process_gw_listener	Check presence of gwservices process	1	45	check_local_procs_arg!1:3!1:3!groundwork/foundation/container/jpp/standalone	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
180	local_process_mysqld	gwsn-local_mysqld	1	40	check_local_procs_string!10!20!mysqld	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
181	local_process_mysqld_safe	gwsn-local_mysqld_safe	1	40	check_local_procs_string!1!2!mysqld_safe	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
182	local_process_nagios	Check NSCA port at host	1	43	\N	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
186	tcp_gw_listener	Check NSCA port at host	1	270	check_tcp_gw_listener!5!9	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
187	tcp_http_port	Check HTTP server on Port at host	1	54	check_http_port!3!5!80	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
188	tcp_nsca	Check NSCA port at host	1	42	check_tcp_nsca!5!9	\N	\N	<?xml version="1.0" ?>\n<data>\n  <prop name="apply_services"><![CDATA[replace]]>\n  </prop>\n  <prop name="apply_check"><![CDATA[checked]]>\n  </prop>\n</data>\n	\N
189	local_users	gwsn-local_users	1	16	check_local_users!5!20	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
190	local_cpu_httpd	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!httpd	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
191	local_cpu_java	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!java	\N	\N	<?xml version="1.0" ?>\n<data>\n  <prop name="apply_services"><![CDATA[replace]]>\n  </prop>\n  <prop name="apply_check"><![CDATA[checked]]>\n  </prop>\n</data>\n	\N
192	local_cpu_mysql	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!mysql	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
193	local_cpu_nagios	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!nagios	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
194	local_cpu_perl	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!perl	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
195	local_cpu_snmptrapd	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!snmptrapd	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
196	local_cpu_snmptt	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!snmptt	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
197	local_cpu_syslog-ng	gwsn-local_mysql_engine	1	267	check_local_proc_cpu!40!50!syslog-ng	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
198	local_load_stack	Check the local load on this unix server	1	1	check_local_load!5,4,3!10,8,6	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
199	local_mem_httpd	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!httpd	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
200	local_mem_java	gwsn-local_mysql_engine	1	268	check_local_proc_mem!40!50!java	\N	\N	<?xml version="1.0" ?>\n<data>\n  <prop name="apply_services"><![CDATA[replace]]>\n  </prop>\n  <prop name="apply_check"><![CDATA[checked]]>\n  </prop>\n</data>\n	\N
201	local_mem_mysql	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!mysql	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
202	local_mem_nagios	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!nagios	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
203	local_mem_perl	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!perl	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
204	local_mem_snmptrapd	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!snmptrapd	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
205	local_mem_snmpttd	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!snmptt	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
206	local_mem_syslog-ng	gwsn-local_mysql_engine	1	268	check_local_proc_mem!20!30!syslog-ng	\N	\N	<?xml version="1.0" ?>\n<data>\n</data>	\N
212	ssh_cpu_proc	gwsn-by_ssh_load	1	272	check_by_ssh_cpu_proc!<warn>!<crit>!<procname>	\N	2	<?xml version="1.0" ?>\n<data>\n  <prop name="dependency"><![CDATA[ssh_depend]]>\n  </prop>\n</data>	\N
224	ssh_mem_proc	gwsn-by_ssh_load	1	273	check_by_ssh_mem_proc!<warn>!<crit>!<procname>	\N	2	<?xml version="1.0" ?>\n<data>\n  <prop name="dependency"><![CDATA[ssh_depend]]>\n  </prop>\n</data>	\N
230	tcp_mysql	check http server at host	1	20	check_tcp!3306	\N	1	<?xml version="1.0" ?>\n<data>\n</data>	\N
232	local_swap	ssh_swap	1	46	check_local_swap!20%!10%	\N	3	<?xml version="1.0" ?>\n<data>\n  <prop name="dependency"><![CDATA[ssh_depend]]>\n  </prop>\n</data>	\N
233	cacti	\N	1	275	check_msg!3!"You actively checked a passive service, check your configuration"	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
234	aix_disk_root	Check the local root-disk usage on this unix server	2	\N	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
235	aix_load	Check the local load on this unix server	2	\N	\N	\N	2	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
236	aix_process_count	Check the number of processes on this server	2	\N	\N	\N	1	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
237	aix_swap	Check the local swap use on this server	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
238	gdma_poller	GDMA poller process status	2	\N	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
239	gdma_spooler	GDMA spooler process status	2	\N	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
240	linux_disk_root	Check the local root-disk usage on this unix server	2	\N	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
241	linux_load	Check the local load on this unix server	2	\N	\N	\N	2	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
242	linux_mem	Check the local memory usage on this unix server	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
243	linux_process_count	Check the number of processes on this server	2	\N	\N	\N	1	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
244	linux_swap	Check the local swap use on this server	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
245	linux_uptime	Check how long this server has been running	2	\N	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
246	solaris_disk_root	Check the local root-disk usage on this unix server	2	\N	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
247	solaris_load	Check the local load on this unix server	2	\N	\N	\N	2	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
248	solaris_process_count	Check the number of processes on this server	2	\N	\N	\N	1	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
249	solaris_swap	Check the local swap use on this server	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
250	gdma_21_wmi_cpu	desc-gdma_wmi_cpu	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
251	gdma_21_wmi_disk_C	desc-gdma_wmi_disk_C	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
252	gdma_21_wmi_disk_all	desc-gdma_wmi_disk_C	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
253	gdma_21_wmi_disktransfers	desc-gdma_wmi_disktransfers	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
254	gdma_21_wmi_mem	desc-gdma_wmi_mem	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
255	gdma_21_wmi_memory_pages	desc-gdma_wmi_memory_pages	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
256	gdma_21_wmi_uptime	desc-gdma_wmi_cpu	2	\N	\N	\N	3	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
257	local_grafana-server	Check the local load on this unix server	1	277	check_grafana	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
258	local_process_grafana-server	gwsn-local_mysqld_safe	1	40	check_local_procs_string!1:1!1:1!grafana/bin/grafana-server	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
259	local_influxdb	Check the local load on this unix server	1	278	check_influxdb	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
260	local_process_influxd	gwsn-local_mysqld_safe	1	40	check_local_procs_string!1:1!1:1!influxdb/bin/influxd	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
261	windows_cpu	\N	1	281	check_wmi_plus_cpu!50!80	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
262	windows_cpu_queue	\N	1	282	check_wmi_plus_cpuq!5!10	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
263	windows_disk_C	\N	1	283	check_wmi_plus_disk!C!80!95	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
264	windows_disks	\N	1	283	check_wmi_plus_disk!.!80!95	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
265	windows_eventlog	\N	1	284	check_wmi_plus_eventlog!System!1!12!10!15	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
266	windows_mem	\N	1	285	check_wmi_plus_mem!70!90	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
267	windows_net	\N	1	286	check_wmi_plus_net!'Local'!_SendBytesUtilisation=60,_ReceiveBytesUtilisation=60!_SendBytesUtilisation=90,_ReceiveBytesUtilisation=90,PacketsReceivedErrors=1	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
268	windows_time_sync	\N	1	287	check_wmi_plus_time!-1:1!-2:2	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>	\N
\.


--
-- Data for Name: contact_service_name; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_service_name (contact_id, servicename_id) FROM stdin;
\.


--
-- Data for Name: service_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY service_templates (servicetemplate_id, name, parent_id, check_period, notification_period, check_command, command_line, event_handler, data, comment) FROM stdin;
1	generic-service	\N	3	3	\N	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retry_check_interval"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="is_volatile"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[3]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[u,c,w,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="normal_check_interval"><![CDATA[10]]>\n  </prop>\n  <prop name="obsess_over_service"><![CDATA[1]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[60]]>\n  </prop>\n</data>	# Generic service definition template - This is NOT a real service, just a template!
2	gdma	\N	3	3	276	check_gdma_fresh!"Stale Status"	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="retry_check_interval"><![CDATA[1]]>\n  </prop>\n  <prop name="flap_detection_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="check_freshness"><![CDATA[1]]>\n  </prop>\n  <prop name="event_handler_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="notifications_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="active_checks_enabled"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="process_perf_data"><![CDATA[1]]>\n  </prop>\n  <prop name="is_volatile"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="freshness_threshold"><![CDATA[900]]>\n  </prop>\n  <prop name="passive_checks_enabled"><![CDATA[1]]>\n  </prop>\n  <prop name="retain_status_information"><![CDATA[1]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[1]]>\n  </prop>\n  <prop name="notification_options"><![CDATA[u,c,w,r]]>\n  </prop>\n  <prop name="retain_nonstatus_information"><![CDATA[1]]>\n  </prop>\n  <prop name="normal_check_interval"><![CDATA[10]]>\n  </prop>\n  <prop name="obsess_over_service"><![CDATA[1]]>\n  </prop>\n  <prop name="notification_interval"><![CDATA[15]]>\n  </prop>\n</data>	\N
\.


--
-- Data for Name: contact_service_template; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contact_service_template (contact_id, servicetemplate_id) FROM stdin;
1	1
\.


--
-- Name: contact_templates_contacttemplate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('contact_templates_contacttemplate_id_seq', 2, true);


--
-- Data for Name: contactgroups; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroups (contactgroup_id, name, alias, comment) FROM stdin;
1	nagiosadmin	Linux Administrators	# 'linux-admins' contact group definition
\.


--
-- Data for Name: contactgroup_contact; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_contact (contactgroup_id, contact_id) FROM stdin;
1	1
1	2
\.


--
-- Data for Name: contactgroup_group; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_group (contactgroup_id, group_id) FROM stdin;
\.


--
-- Data for Name: contactgroup_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_host (contactgroup_id, host_id) FROM stdin;
1	1
\.


--
-- Data for Name: contactgroup_host_profile; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_host_profile (contactgroup_id, hostprofile_id) FROM stdin;
\.


--
-- Data for Name: contactgroup_host_template; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_host_template (contactgroup_id, hosttemplate_id) FROM stdin;
1	1
\.


--
-- Data for Name: contactgroup_hostgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_hostgroup (contactgroup_id, hostgroup_id) FROM stdin;
\.


--
-- Data for Name: contactgroup_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_service (contactgroup_id, service_id) FROM stdin;
\.


--
-- Data for Name: contactgroup_service_name; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_service_name (contactgroup_id, servicename_id) FROM stdin;
\.


--
-- Data for Name: contactgroup_service_template; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY contactgroup_service_template (contactgroup_id, servicetemplate_id) FROM stdin;
1	1
\.


--
-- Name: contactgroups_contactgroup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('contactgroups_contactgroup_id_seq', 1, true);


--
-- Name: contacts_contact_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('contacts_contact_id_seq', 2, true);


--
-- Data for Name: datatype; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY datatype (datatype_id, type, location) FROM stdin;
\.


--
-- Name: datatype_datatype_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('datatype_datatype_id_seq', 1, false);


--
-- Data for Name: discover_filter; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY discover_filter (filter_id, name, type, filter) FROM stdin;
\.


--
-- Name: discover_filter_filter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('discover_filter_filter_id_seq', 1, false);


--
-- Data for Name: import_schema; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_schema (schema_id, name, delimiter, description, type, sync_object, smart_name, hostprofile_id, data_source) FROM stdin;
\.


--
-- Data for Name: discover_group; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY discover_group (group_id, name, description, config, schema_id) FROM stdin;
\.


--
-- Data for Name: discover_group_filter; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY discover_group_filter (group_id, filter_id) FROM stdin;
\.


--
-- Name: discover_group_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('discover_group_group_id_seq', 1, false);


--
-- Data for Name: discover_method; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY discover_method (method_id, name, description, config, type) FROM stdin;
\.


--
-- Data for Name: discover_group_method; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY discover_group_method (group_id, method_id) FROM stdin;
\.


--
-- Data for Name: discover_method_filter; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY discover_method_filter (method_id, filter_id) FROM stdin;
\.


--
-- Name: discover_method_method_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('discover_method_method_id_seq', 1, false);


--
-- Data for Name: time_periods; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY time_periods (timeperiod_id, name, alias, comment) FROM stdin;
1	none	No Time Is A Good Time	'none' timeperiod definition
2	workhours	"Normal" Working Hours	'workhours' timeperiod definition
3	24x7	24 Hours A Day, 7 Days A Week	All day, every day.
4	nonworkhours	Non-Work Hours	'nonworkhours' timeperiod definition
\.


--
-- Data for Name: escalation_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY escalation_templates (template_id, name, type, data, comment, escalation_period) FROM stdin;
\.


--
-- Name: escalation_templates_template_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('escalation_templates_template_id_seq', 1, false);


--
-- Data for Name: escalation_tree_template; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY escalation_tree_template (tree_id, template_id) FROM stdin;
\.


--
-- Name: escalation_trees_tree_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('escalation_trees_tree_id_seq', 1, false);


--
-- Name: extended_host_info_templates_hostextinfo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('extended_host_info_templates_hostextinfo_id_seq', 1, false);


--
-- Data for Name: extended_info_coords; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY extended_info_coords (host_id, data) FROM stdin;
\.


--
-- Name: extended_service_info_templates_serviceextinfo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('extended_service_info_templates_serviceextinfo_id_seq', 5, true);


--
-- Data for Name: externals; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY externals (external_id, name, description, type, display, handler) FROM stdin;
1	aix_disk_root	\N	service	Check_gdma_aix_disk_root[1]_Enable="ON"\nCheck_gdma_aix_disk_root[1]_Service="aix_disk_root"\nCheck_gdma_aix_disk_root[1]_Command="check_disk -w 10% -c 5% -t 10 -p /"\nCheck_gdma_aix_disk_root[1]_Check_Interval="1"	\N
2	aix_load	\N	service	Check_gdma_aix_load[1]_Enable="ON"\nCheck_gdma_aix_load[1]_Service="aix_load"\nCheck_gdma_aix_load[1]_Command="check_load -r -w 90,75,60 -c 100,95,90"\nCheck_gdma_aix_load[1]_Check_Interval="1"	\N
3	aix_process_count	\N	service	Check_gdma_aix_process_count[1]_Enable="ON"\nCheck_gdma_aix_process_count[1]_Service="aix_process_count"\nCheck_gdma_aix_process_count[1]_Command="check_procs -w 80 -c 100"\nCheck_gdma_aix_process_count[1]_Check_Interval="1"	\N
4	aix_swap	\N	service	Check_gdma_aix_swap[1]_Enable="ON"\nCheck_gdma_aix_swap[1]_Service="aix_swap"\nCheck_gdma_aix_swap[1]_Command="check_swap -w 10% -c 5%"\nCheck_gdma_aix_swap[1]_Check_Interval="1"	\N
5	gdma-aix	\N	host	### Start "gdma-aix" host externals ###\n\n# How often to attempt to pull the configuration.\n# Specified as how many Poller_Proc_Interval periods between attempts.\n#ConfigFile_Pull_Cycle = "1"\n\n# URL timeout in seconds when trying to fetch the configuration via HTTP/S.\n#ConfigPull_Timeout = "10"\n\n# Enable/Disable autoconfiguration.\n# This needs to be explicitly set "off" to override the gdma_auto.conf contents.\n# Otherwise, the agent will never leave autoconfiguration mode.\nEnable_Auto = "off"\n\n# Enable target logging.\n# Leave this off except when debugging.\n# Enable_Local_Logging = "off"\n\n# Directory path with respect to the Apache document root,\n# which contains the host config file on the server.\n#GDMAConfigDir ="gdma"\n\n# Hostname under which to submit autoconfiguration results.\n#GDMA_Auto_Host = "gdma-autohost"\n\n# Servicename under which to submit autoconfiguration results.\n#GDMA_Auto_Service = "gdma_auto"\n\n# Log directory location on GDMA client.\n#Logdir = "/usr/local/groundwork/gdma/log/"\n\n# Path to the local plugins.\n#Poller_Plugin_Directory = "/usr/local/groundwork/gdma/libexec"\n\n# Default timeout for plugin execution, specified in seconds.\n# Can be overridden by Check_{service}_Timeout for a given service.\n#Poller_Plugin_Timeout = "5"\n\n# Time in seconds for the polling interval.\n# Look at service gdma_poller run times if this is set to less than the time it takes\n# to run all checks for the host.  Then checks will be killed by GDMA.\n#Poller_Proc_Interval = "600"\n\n# Timer to revert to autoconfiguration mode if configuration cannot be pulled.\n# Defaults to 1 day.\n#Poller_Pull_Failure_Interval = "86400"\n\n# Service name under which to submit poller notifications.\n#Poller_Service = "gdma_poller"\n\n# Poller_Status is left defaulted (typically set on in gdma_auto.conf, to\n# enable heartbeat messages about polling status).  This should be on if your\n# setup includes the Poller_Service service (named above) for this host.\n#Poller_Status = "On"\n\n# Number of results per batch for send_nsca.\n#Spooler_Batch_Size = "20"\n\n# Number of times to retry sending spooled results.\n# Specified as a multiple of the Spooler_Proc_Interval time.\n#Spooler_Max_Retries = "10"\n\n# The NSCA port.\n#Spooler_NSCA_Port = "5667"\n\n# Send NSCA Executable location.\n#Spooler_NSCA_Program = "/usr/local/groundwork/gdma/bin/send_nsca.pl"\n\n# Timeout in seconds for NSCA port check.\n#Spooler_NSCA_Timeout = "5"\n\n# Execution interval for spool processor, in seconds; min 10, max 3500.\n# Setting this too low will increase processing overhead on the GDMA client.\n#Spooler_Proc_Interval = "30"\n\n# Spooled result retention time in seconds.\n# Setting this to something greater than the bronx listener_max_packet_age\n# will result in lost check results.\n#Spooler_Retention_Time = "900"\n\n# Service name under which to submit spooler notifications.\n#Spooler_Service = "gdma_spooler"\n\n# Spooler_Status is left at "updates", which does not send heartbeats\n# but does send spooled message summaries.\nSpooler_Status = "Updates"\n\n# Target_Server is the host (or hosts) to receive GDMA results.\n# This is also the location where configurations are pulled from.\n# Multiple entries may be specified, separated by commas.\n# Target_Server = "http://gdma-autohost"\n\n# Secondary target location.  Only used in N+1 HA configurations.\n#Target_Server_Secondary = "https://gdma-autohost"\n\n### End "gdma-aix" host externals ###\n	\N
6	linux_disk_root	\N	service	Check_gdma_linux_disk_root[1]_Enable="ON"\nCheck_gdma_linux_disk_root[1]_Service="linux_disk_root"\nCheck_gdma_linux_disk_root[1]_Command="check_disk -w 10% -c 5% -t 10 -p /"\nCheck_gdma_linux_disk_root[1]_Check_Interval="1"	\N
7	linux_load	\N	service	Check_gdma_linux_load[1]_Enable="ON"\nCheck_gdma_linux_load[1]_Service="linux_load"\nCheck_gdma_linux_load[1]_Command="check_load -r -w 90,75,60 -c 100,95,90"\nCheck_gdma_linux_load[1]_Check_Interval="1"	\N
8	linux_mem	\N	service	Check_gdma_linux_mem[1]_Enable="ON"\nCheck_gdma_linux_mem[1]_Service="linux_mem"\nCheck_gdma_linux_mem[1]_Command="check_mem.pl -f -w 20 -c 10"\nCheck_gdma_linux_mem[1]_Check_Interval="1"	\N
9	linux_process_count	\N	service	Check_gdma_linux_process_count[1]_Enable="ON"\nCheck_gdma_linux_process_count[1]_Service="linux_process_count"\nCheck_gdma_linux_process_count[1]_Command="check_procs -w 80 -c 100"\nCheck_gdma_linux_process_count[1]_Check_Interval="1"	\N
10	linux_swap	\N	service	Check_gdma_linux_swap[1]_Enable="ON"\nCheck_gdma_linux_swap[1]_Service="linux_swap"\nCheck_gdma_linux_swap[1]_Command="check_swap -w 10% -c 5%"\nCheck_gdma_linux_swap[1]_Check_Interval="1"	\N
11	linux_uptime	\N	service	Check_gdma_linux_uptime[1]_Enable="ON"\nCheck_gdma_linux_uptime[1]_Service="linux_uptime"\nCheck_gdma_linux_uptime[1]_Command="check_system_uptime.pl -w 1800 -c 900"\nCheck_gdma_linux_uptime[1]_Check_Interval="1"	\N
12	gdma-linux	\N	host	### Start "gdma-linux" host externals ###\n\n# How often to attempt to pull the configuration.\n# Specified as how many Poller_Proc_Interval periods between attempts.\n#ConfigFile_Pull_Cycle = "1"\n\n# URL timeout in seconds when trying to fetch the configuration via HTTP/S.\n#ConfigPull_Timeout = "10"\n\n# Enable/Disable autoconfiguration.\n# This needs to be explicitly set "off" to override the gdma_auto.conf contents.\n# Otherwise, the agent will never leave autoconfiguration mode.\nEnable_Auto = "off"\n\n# Enable target logging.\n# Leave this off except when debugging.\n# Enable_Local_Logging = "off"\n\n# Directory path with respect to the Apache document root,\n# which contains the host config file on the server.\n#GDMAConfigDir ="gdma"\n\n# Hostname under which to submit autoconfiguration results.\n#GDMA_Auto_Host = "gdma-autohost"\n\n# Servicename under which to submit autoconfiguration results.\n#GDMA_Auto_Service = "gdma_auto"\n\n# Log directory location on GDMA client.\n#Logdir = "/usr/local/groundwork/gdma/log/"\n\n# Path to the local plugins.\n#Poller_Plugin_Directory = "/usr/local/groundwork/gdma/libexec"\n\n# Default timeout for plugin execution, specified in seconds.\n# Can be overridden by Check_{service}_Timeout for a given service.\n#Poller_Plugin_Timeout = "5"\n\n# Time in seconds for the polling interval.\n# Look at service gdma_poller run times if this is set to less than the time it takes\n# to run all checks for the host.  Then checks will be killed by GDMA.\n#Poller_Proc_Interval = "600"\n\n# Timer to revert to autoconfiguration mode if configuration cannot be pulled.\n# Defaults to 1 day.\n#Poller_Pull_Failure_Interval = "86400"\n\n# Service name under which to submit poller notifications.\n#Poller_Service = "gdma_poller"\n\n# Poller_Status is left defaulted (typically set on in gdma_auto.conf, to\n# enable heartbeat messages about polling status).  This should be on if your\n# setup includes the Poller_Service service (named above) for this host.\n#Poller_Status = "On"\n\n# Number of results per batch for send_nsca.\n#Spooler_Batch_Size = "20"\n\n# Number of times to retry sending spooled results.\n# Specified as a multiple of the Spooler_Proc_Interval time.\n#Spooler_Max_Retries = "10"\n\n# The NSCA port.\n#Spooler_NSCA_Port = "5667"\n\n# Send NSCA Executable location.\n#Spooler_NSCA_Program = "/usr/local/groundwork/gdma/bin/send_nsca.pl"\n\n# Timeout in seconds for NSCA port check.\n#Spooler_NSCA_Timeout = "5"\n\n# Execution interval for spool processor, in seconds; min 10, max 3500.\n# Setting this too low will increase processing overhead on the GDMA client.\n#Spooler_Proc_Interval = "30"\n\n# Spooled result retention time in seconds.\n# Setting this to something greater than the bronx listener_max_packet_age\n# will result in lost check results.\n#Spooler_Retention_Time = "900"\n\n# Service name under which to submit spooler notifications.\n#Spooler_Service = "gdma_spooler"\n\n# Spooler_Status is left at "updates", which does not send heartbeats\n# but does send spooled message summaries.\nSpooler_Status = "Updates"\n\n# Target_Server is the host (or hosts) to receive GDMA results.\n# This is also the location where configurations are pulled from.\n# Multiple entries may be specified, separated by commas.\n# Target_Server = "http://gdma-autohost"\n\n# Secondary target location.  Only used in N+1 HA configurations.\n#Target_Server_Secondary = "https://gdma-autohost"\n\n### End "gdma-linux" host externals ###\n	\N
13	solaris_disk_root	\N	service	Check_gdma_solaris_disk_root[1]_Enable="ON"\nCheck_gdma_solaris_disk_root[1]_Service="solaris_disk_root"\nCheck_gdma_solaris_disk_root[1]_Command="check_disk -w 10% -c 5% -t 10 -p /"\nCheck_gdma_solaris_disk_root[1]_Check_Interval="1"	\N
14	solaris_load	\N	service	Check_gdma_solaris_load[1]_Enable="ON"\nCheck_gdma_solaris_load[1]_Service="solaris_load"\nCheck_gdma_solaris_load[1]_Command="check_load -r -w 90,75,60 -c 100,95,90"\nCheck_gdma_solaris_load[1]_Check_Interval="1"	\N
15	solaris_process_count	\N	service	Check_gdma_solaris_process_count[1]_Enable="ON"\nCheck_gdma_solaris_process_count[1]_Service="solaris_process_count"\nCheck_gdma_solaris_process_count[1]_Command="check_procs -w 80 -c 100"\nCheck_gdma_solaris_process_count[1]_Check_Interval="1"	\N
16	solaris_swap	\N	service	Check_gdma_solaris_swap[1]_Enable="ON"\nCheck_gdma_solaris_swap[1]_Service="solaris_swap"\nCheck_gdma_solaris_swap[1]_Command="check_swap -w 10% -c 5%"\nCheck_gdma_solaris_swap[1]_Check_Interval="1"	\N
17	gdma-solaris	\N	host	### Start "gdma-solaris" host externals ###\n\n# How often to attempt to pull the configuration.\n# Specified as how many Poller_Proc_Interval periods between attempts.\n#ConfigFile_Pull_Cycle = "1"\n\n# URL timeout in seconds when trying to fetch the configuration via HTTP/S.\n#ConfigPull_Timeout = "10"\n\n# Enable/Disable autoconfiguration.\n# This needs to be explicitly set "off" to override the gdma_auto.conf contents.\n# Otherwise, the agent will never leave autoconfiguration mode.\nEnable_Auto = "off"\n\n# Enable target logging.\n# Leave this off except when debugging.\n# Enable_Local_Logging = "off"\n\n# Directory path with respect to the Apache document root,\n# which contains the host config file on the server.\n#GDMAConfigDir ="gdma"\n\n# Hostname under which to submit autoconfiguration results.\n#GDMA_Auto_Host = "gdma-autohost"\n\n# Servicename under which to submit autoconfiguration results.\n#GDMA_Auto_Service = "gdma_auto"\n\n# Log directory location on GDMA client.\n#Logdir = "/usr/local/groundwork/gdma/log/"\n\n# Path to the local plugins.\n#Poller_Plugin_Directory = "/usr/local/groundwork/gdma/libexec"\n\n# Default timeout for plugin execution, specified in seconds.\n# Can be overridden by Check_{service}_Timeout for a given service.\n#Poller_Plugin_Timeout = "5"\n\n# Time in seconds for the polling interval.\n# Look at service gdma_poller run times if this is set to less than the time it takes\n# to run all checks for the host.  Then checks will be killed by GDMA.\n#Poller_Proc_Interval = "600"\n\n# Timer to revert to autoconfiguration mode if configuration cannot be pulled.\n# Defaults to 1 day.\n#Poller_Pull_Failure_Interval = "86400"\n\n# Service name under which to submit poller notifications.\n#Poller_Service = "gdma_poller"\n\n# Poller_Status is left defaulted (typically set on in gdma_auto.conf, to\n# enable heartbeat messages about polling status).  This should be on if your\n# setup includes the Poller_Service service (named above) for this host.\n#Poller_Status = "On"\n\n# Number of results per batch for send_nsca.\n#Spooler_Batch_Size = "20"\n\n# Number of times to retry sending spooled results.\n# Specified as a multiple of the Spooler_Proc_Interval time.\n#Spooler_Max_Retries = "10"\n\n# The NSCA port.\n#Spooler_NSCA_Port = "5667"\n\n# Send NSCA Executable location.\n#Spooler_NSCA_Program = "/usr/local/groundwork/gdma/bin/send_nsca.pl"\n\n# Timeout in seconds for NSCA port check.\n#Spooler_NSCA_Timeout = "5"\n\n# Execution interval for spool processor, in seconds; min 10, max 3500.\n# Setting this too low will increase processing overhead on the GDMA client.\n#Spooler_Proc_Interval = "30"\n\n# Spooled result retention time in seconds.\n# Setting this to something greater than the bronx listener_max_packet_age\n# will result in lost check results.\n#Spooler_Retention_Time = "900"\n\n# Service name under which to submit spooler notifications.\n#Spooler_Service = "gdma_spooler"\n\n# Spooler_Status is left at "updates", which does not send heartbeats\n# but does send spooled message summaries.\nSpooler_Status = "Updates"\n\n# Target_Server is the host (or hosts) to receive GDMA results.\n# This is also the location where configurations are pulled from.\n# Multiple entries may be specified, separated by commas.\n# Target_Server = "http://gdma-autohost"\n\n# Secondary target location.  Only used in N+1 HA configurations.\n#Target_Server_Secondary = "https://gdma-autohost"\n\n### End "gdma-solaris" host externals ###\n	\N
18	gdma_21_wmi_cpu	\N	service	Check_gdma_wmi_cpu[1]_Enable="ON"\nCheck_gdma_wmi_cpu[1]_Service="gdma_21_wmi_cpu"\nCheck_gdma_wmi_cpu[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\check_cpu_load_percentage.vbs' -h $Monitor_Host$ -inst _Total -t 80,90"\nCheck_gdma_wmi_cpu[1]_Check_Interval="1"	\N
19	gdma_21_wmi_disk_C	\N	service	Check_gdma_wmi_disk_C[1]_Enable="ON"\nCheck_gdma_wmi_disk_C[1]_Service="gdma_21_wmi_disk_C"\nCheck_gdma_wmi_disk_C[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\check_disks_percentage_space_used.vbs' -h $Monitor_Host$ -inst C: -t 80,90"\nCheck_gdma_wmi_disk_C[1]_Check_Interval="1"	\N
20	gdma_21_wmi_disk_all	\N	service	Check_gdma_wmi_disk_all[1]_Enable="ON"\nCheck_gdma_wmi_disk_all[1]_Service="gdma_21_wmi_disk_all"\nCheck_gdma_wmi_disk_all[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\check_disks_percentage_space_used.vbs' -h $Monitor_Host$ -inst * -t 80,90"\nCheck_gdma_wmi_disk_all[1]_Check_Interval="1"	\N
21	gdma_21_wmi_disktransfers	\N	service	Check_gdma_wmi_disktransfers[1]_Enable="ON"\nCheck_gdma_wmi_disktransfers[1]_Service="gdma_21_wmi_disktransfers"\nCheck_gdma_wmi_disktransfers[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\check_counter_counter.vbs' -h $Monitor_Host$ -class Win32_PerfRawData_PerfDisk_PhysicalDisk -inst Name=_Total -prop DiskTransfersPersec -w 10 -c 20"\nCheck_gdma_wmi_disktransfers[1]_Check_Interval="1"	\N
22	gdma_21_wmi_mem	\N	service	Check_gdma_wmi_mem[1]_Enable="ON"\nCheck_gdma_wmi_mem[1]_Service="gdma_21_wmi_mem"\nCheck_gdma_wmi_mem[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\check_memory_percentage_space_used.vbs' -h $Monitor_Host$ -inst _Total -t 80,90"\nCheck_gdma_wmi_mem[1]_Check_Interval="1"	\N
23	gdma_21_wmi_memory_pages	\N	service	Check_gdma_wmi_memory_pages[1]_Enable="ON"\nCheck_gdma_wmi_memory_pages[1]_Service="gdma_21_wmi_memory_pages"\nCheck_gdma_wmi_memory_pages[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\check_counter_counter.vbs' -h $Monitor_Host$ -class Win32_PerfRawData_PerfOS_Memory -inst * -prop PagesPerSec -w 10 -c 20"\nCheck_gdma_wmi_memory_pages[1]_Check_Interval="1"	\N
24	gdma_21_wmi_uptime	\N	service	Check_gdma_wmi_uptime[1]_Enable="ON"\nCheck_gdma_wmi_uptime[1]_Service="gdma_21_wmi_uptime"\nCheck_gdma_wmi_uptime[1]_Command="cscript.exe //nologo //T:60 '$Plugin_Directory$\\v2\\get_system_uptime.vbs' -h 127.0.0.1 -w 1800 -c 900"\nCheck_gdma_wmi_uptime[1]_Check_Interval="1"	\N
25	gdma-windows	\N	host	### Start "gdma-windows" host externals ###\n\n# How often to attempt to pull the configuration.\n# Specified as how many Poller_Proc_Interval periods between attempts.\n#ConfigFile_Pull_Cycle = "1"\n\n# URL timeout in seconds when trying to fetch the configuration via HTTP/S.\n#ConfigPull_Timeout = "10"\n\n# Enable/Disable autoconfiguration.\n# This needs to be explicitly set "off" to override the gdma_auto.conf contents.\n# Otherwise, the agent will never leave autoconfiguration mode.\nEnable_Auto = "off"\n\n# Enable target logging.\n# Leave this off except when debugging.\nEnable_Local_Logging = "off"\n\n# Directory path with respect to the Apache document root,\n# which contains the host config file on the server.\n#GDMAConfigDir ="gdma"\n\n# Hostname under which to submit autoconfiguration results.\n#GDMA_Auto_Host = "gdma-autohost"\n\n# Servicename under which to submit autoconfiguration results.\n#GDMA_Auto_Service = "gdma_auto"\n\n# Log directory location on GDMA client.\n# 32-bit Windows:\n#Logdir = "C:\\Program Files\\groundwork\\gdma\\log\\"\n# 64-bit Windows:\n#Logdir = "C:\\Program Files (x86)\\groundwork\\gdma\\log\\"\n\n# Path to the local plugins.\n# 32-bit Windows:\n#Poller_Plugin_Directory = "C:\\Program Files\\groundwork\\gdma\\libexec"\n# 64-bit Windows:\n#Poller_Plugin_Directory = "C:\\Program Files (x86)\\groundwork\\gdma\\libexec"\n\n# Default timeout for plugin execution, specified in seconds.\n# Can be overridden by Check_{service}_Timeout for a given service.\n#Poller_Plugin_Timeout = "20"\n\n# Time in seconds for the polling interval.\n# Look at service gdma_poller run times if this is set to less than the time it takes\n# to run all checks for the host.  Then checks will be killed by GDMA.\n#Poller_Proc_Interval = "600"\n\n# Timer to revert to autoconfiguration mode if configuration cannot be pulled.\n# Defaults to 1 day.\n#Poller_Pull_Failure_Interval = "86400"\n\n# Service name under which to submit poller notifications.\n#Poller_Service = "gdma_poller"\n\n# Poller_Status is left defaulted (typically set on in gdma_auto.conf, to\n# enable heartbeat messages about polling status).  This should be on if your\n# setup includes the Poller_Service service (named above) for this host.\n#Poller_Status = "On"\n\n# Number of results per batch for send_nsca.\n#Spooler_Batch_Size = "20"\n\n# Number of times to retry sending spooled results.\n# Specified as a multiple of the Spooler_Proc_Interval time.\n#Spooler_Max_Retries = "10"\n\n# The NSCA port.\n#Spooler_NSCA_Port = "5667"\n\n# Send NSCA Executable location.\n# 32-bit Windows:\n#Spooler_NSCA_Program = "C:\\Program Files\\groundwork\\gdma\\bin\\send_nsca.exe"\n# 64-bit Windows:\n#Spooler_NSCA_Program = "C:\\Program Files (x86)\\groundwork\\gdma\\bin\\send_nsca.exe"\n\n# Timeout in seconds for NSCA port check.\n#Spooler_NSCA_Timeout = "5"\n\n# Execution interval for spool processor, in seconds.\n# Setting this too low will increase processing overhead on the GDMA client.\n#Spooler_Proc_Interval = "30"\n\n# Spooled result retention time in seconds.\n# Setting this to something greater than the bronx listener_max_packet_age\n# will result in lost check results.\n#Spooler_Retention_Time = "900"\n\n# Service name under which to submit spooler notifications.\n#Spooler_Service = "gdma_spooler"\n\n# Spooler_Status is left at "updates", which does not send heartbeats\n# but does send spooled message summaries.\nSpooler_Status = "Updates"\n\n# Target_Server is the host (or hosts) to receive GDMA results.\n# This is also the location where configurations are pulled from.\n# Multiple entries may be specified, separated by commas.\n#Target_Server = "http://gdma-autohost"\n\n# Secondary target location.  Only used in N+1 HA configurations.\n#Target_Server_Secondary = "https://gdma-autohost"\n\n### End "gdma-windows" host externals ###	\N
\.


--
-- Data for Name: external_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY external_host (external_id, host_id, data, modified) FROM stdin;
\.


--
-- Data for Name: external_host_profile; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY external_host_profile (external_id, hostprofile_id) FROM stdin;
5	5
12	6
17	7
25	8
\.


--
-- Data for Name: external_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY external_service (external_id, host_id, service_id, data, modified) FROM stdin;
\.


--
-- Data for Name: external_service_names; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY external_service_names (external_id, servicename_id) FROM stdin;
1	234
2	235
3	236
4	237
6	240
7	241
8	242
9	243
10	244
11	245
13	246
14	247
15	248
16	249
18	250
19	251
20	252
21	253
22	254
23	255
24	256
\.


--
-- Name: externals_external_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('externals_external_id_seq', 25, true);


--
-- Data for Name: host_dependencies; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY host_dependencies (host_id, parent_id, data, comment) FROM stdin;
\.


--
-- Data for Name: host_overrides; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY host_overrides (host_id, check_period, notification_period, check_command, event_handler, data) FROM stdin;
1	\N	3	7	\N	<?xml version="1.0" ?>\n<data>\n <prop name="max_check_attempts"><![CDATA[10]]>\n </prop>\n <prop name="notification_options"><![CDATA[d,u,r]]>\n </prop>\n <prop name="notification_interval"><![CDATA[480]]>\n </prop>\n <prop name="notification_period"><![CDATA[3]]>\n </prop>\n</data>
\.


--
-- Data for Name: host_parent; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY host_parent (host_id, parent_id) FROM stdin;
\.


--
-- Data for Name: host_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY host_service (host_service_id, host, service, label, dataname, datatype_id) FROM stdin;
\.


--
-- Name: host_service_host_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('host_service_host_service_id_seq', 1, false);


--
-- Name: host_templates_hosttemplate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('host_templates_hosttemplate_id_seq', 5, true);


--
-- Data for Name: hostgroup_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY hostgroup_host (hostgroup_id, host_id) FROM stdin;
1	1
\.


--
-- Name: hostgroups_hostgroup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('hostgroups_hostgroup_id_seq', 2, true);


--
-- Data for Name: hostprofile_overrides; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY hostprofile_overrides (hostprofile_id, check_period, notification_period, check_command, event_handler, data) FROM stdin;
1	\N	\N	\N	\N	<?xml version="1.0" ?>\n<data>\n </data>
\.


--
-- Name: hosts_host_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('hosts_host_id_seq', 1, true);


--
-- Data for Name: import_column; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_column (column_id, schema_id, name, "position", delimiter) FROM stdin;
\.


--
-- Name: import_column_column_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('import_column_column_id_seq', 1, false);


--
-- Data for Name: import_hosts; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_hosts (import_hosts_id, name, alias, address, hostprofile_id) FROM stdin;
\.


--
-- Name: import_hosts_import_hosts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('import_hosts_import_hosts_id_seq', 1, false);


--
-- Data for Name: import_match; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match (match_id, column_id, name, match_order, match_type, match_string, rule, object, hostprofile_id, servicename_id, arguments) FROM stdin;
\.


--
-- Data for Name: import_match_contactgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match_contactgroup (match_id, contactgroup_id) FROM stdin;
\.


--
-- Data for Name: import_match_group; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match_group (match_id, group_id) FROM stdin;
\.


--
-- Data for Name: import_match_hostgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match_hostgroup (match_id, hostgroup_id) FROM stdin;
\.


--
-- Name: import_match_match_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('import_match_match_id_seq', 1, false);


--
-- Data for Name: import_match_parent; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match_parent (match_id, parent_id) FROM stdin;
\.


--
-- Data for Name: import_match_servicename; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match_servicename (match_id, servicename_id) FROM stdin;
\.


--
-- Data for Name: profiles_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY profiles_service (serviceprofile_id, name, description, data) FROM stdin;
2	ssh-unix	SSH UNIX server generic profile	<?xml version="1.0" ?>\n<data>\n</data>
3	snmp-network	network_snmp	<?xml version="1.0" ?>\n<data>\n</data>
4	service-ping	Ping service profile	<?xml version="1.0" ?>\n<data>\n</data>
5	cacti	Profile containing passive cacti service check	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
6	gdma-23-aix	Base OS service profile for AIX host GDMA checks	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
7	gdma-23-linux	Base OS service profile for Linux host GDMA checks	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
8	gdma-23-solaris	Base OS service profile for Solaris host GDMA checks	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
9	gdma-21-windows	GDMA Windows Server (via WMI)	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
10	grafana-server	Linux Grafana Server checks	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
11	influxdb	Linux InfluxDB checks	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
12	Windows-WMIC-based-checks	Direct checks of Windows systems using WMIC 	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n</data>
\.


--
-- Data for Name: import_match_serviceprofile; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_match_serviceprofile (match_id, serviceprofile_id) FROM stdin;
\.


--
-- Name: import_schema_schema_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('import_schema_schema_id_seq', 1, false);


--
-- Data for Name: import_services; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY import_services (import_services_id, import_hosts_id, description, check_command_id, command_line, command_line_trans, servicename_id, serviceprofile_id) FROM stdin;
\.


--
-- Name: import_services_import_services_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('import_services_import_services_id_seq', 1, false);


--
-- Data for Name: monarch_group_child; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_group_child (group_id, child_id) FROM stdin;
\.


--
-- Data for Name: monarch_group_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_group_host (group_id, host_id) FROM stdin;
\.


--
-- Data for Name: monarch_group_hostgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_group_hostgroup (group_id, hostgroup_id) FROM stdin;
\.


--
-- Data for Name: monarch_macros; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_macros (macro_id, name, value, description) FROM stdin;
\.


--
-- Data for Name: monarch_group_macro; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_group_macro (group_id, macro_id, value) FROM stdin;
\.


--
-- Data for Name: monarch_group_props; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY monarch_group_props (prop_id, group_id, name, type, value) FROM stdin;
\.


--
-- Name: monarch_group_props_prop_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('monarch_group_props_prop_id_seq', 1, false);


--
-- Name: monarch_groups_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('monarch_groups_group_id_seq', 3, true);


--
-- Name: monarch_macros_macro_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('monarch_macros_macro_id_seq', 1, false);


--
-- Data for Name: performanceconfig; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY performanceconfig (performanceconfig_id, host, service, type, enable, parseregx_first, service_regx, label, rrdname, rrdcreatestring, rrdupdatestring, graphcgi, perfidstring, parseregx) FROM stdin;
4	*	snmp_if_	nagios	1	1	1	Interface Statistics	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:in:COUNTER:1800:U:U DS:out:COUNTER:1800:U:U DS:indis:COUNTER:1800:U:U DS:outdis:COUNTER:1800:U:U DS:inerr:COUNTER:1800:U:U  DS:outerr:COUNTER:1800:U:U RRA:AVERAGE:0.5:1:2880 RRA:AVERAGE:0.5:5:4032	$RRDTOOL$ update $RRDNAME$ -t in:out:indis:outdis:inerr:outerr $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$:$VALUE4$:$VALUE5$:$VALUE6$  2>&1		 	SNMP OK - (\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)
5	*	snmp_ifbandwidth_	nagios	1	\N	1	Interface Bandwidth Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:in:COUNTER:1800:U:U DS:out:COUNTER:1800:U:U DS:ifspeed:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ -t in:out:ifspeed $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$ 2>&1		 	SNMP OK - (\\d+)\\s+(\\d+)\\s+(\\d+)
13	*	icmp_ping	nagios	1	0	1	ICMP Ping Response Time	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:rta:GAUGE:1800:U:U DS:pl:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$ 2>&1	'rrdtool graph - --imgformat=PNG --title="ICMP Performance" --rigid --base=1000 --height=120 --width=700 --alt-autoscale-max --lower-limit=0 --vertical-label="Time and Percent" --slope-mode DEF:a="rrd_source":ds_source_1:AVERAGE DEF:b="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=b CDEF:cdefb=a,100,/ AREA:cdefa#43C6DB:"Response Time (ms) " GPRINT:cdefa:LAST:"Current\\:%8.2lf %s" GPRINT:cdefa:AVERAGE:"Average\\:%8.2lf %s" GPRINT:cdefa:MAX:"Maximum\\:%8.2lf %s\\n" LINE1:cdefb#307D7E:"Percent Loss       " GPRINT:cdefb:LAST:"Current\\:%8.2lf %s" GPRINT:cdefb:AVERAGE:"Average\\:%8.2lf %s" GPRINT:cdefb:MAX:"Maximum\\:%8.2lf %s"'		
14	*	local_disk	nagios	1	0	1	Disk Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE \r\n DEF:w="rrd_source":ds_source_1:AVERAGE\r\n DEF:c="rrd_source":ds_source_2:AVERAGE\r\n DEF:m="rrd_source":ds_source_3:AVERAGE\r\n CDEF:cdefa=a,m,/,100,* \r\n CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w\r\n CDEF:cdefc=c\r\n CDEF:cdefm=m  \r\n AREA:a#C35617:"Space Used\\: "\r\n LINE:cdefa#FFCC00:\r\n GPRINT:a:LAST:"%.2lf MB\\l"\r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:"\r\n GPRINT:cdefw:AVERAGE:"%.2lf" \r\n LINE2:cdefc#FF0033:"Critical Threshold\\:" \r\n GPRINT:cdefc:AVERAGE:"%.2lf\\l" \r\n GPRINT:cdefa:AVERAGE:"Percentage Space Used"=%.2lf\r\n GPRINT:cdefm:AVERAGE:"Maximum Capacity"=%.2lf\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF\r\n AREA:cdefws#FFFF00\r\n CDEF:cdefcs=a,cdefc,GT,a,0,IF\r\n AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  -l 0'		 
15	*	local_load	nagios	1	0	0	Load Averages	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE3$:$WARN3$:$CRIT3$ 2>&1	'rrdtool graph - --imgformat=PNG --slope-mode \r\n DEF:a=rrd_source:ds_source_0:AVERAGE \r\n DEF:aw="rrd_source":ds_source_1:AVERAGE\r\n DEF:ac="rrd_source":ds_source_2:AVERAGE\r\n DEF:b=rrd_source:ds_source_3:AVERAGE \r\n DEF:bw="rrd_source":ds_source_4:AVERAGE\r\n DEF:bc="rrd_source":ds_source_5:AVERAGE\r\n DEF:c=rrd_source:ds_source_6:AVERAGE\r\n DEF:cw="rrd_source":ds_source_7:AVERAGE\r\n DEF:cc="rrd_source":ds_source_8:AVERAGE\r\n CDEF:cdefa=a \r\n CDEF:cdefb=b \r\n CDEF:cdefc=c \r\n AREA:cdefa#FF6600:"One Minute Load Average" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf  \r\n GPRINT:cdefa:MAX:"max=%.2lf\\l"\r\n LINE:aw#FFCC33:"1 min avg Warning Threshold" \r\n GPRINT:aw:LAST:"%.1lf"\r\n LINE:ac#FF0000:"1 min avg Critical Threshold"\r\n GPRINT:ac:LAST:"%.1lf\\l"\r\n LINE2:cdefb#3300FF:"Five Minute Load Average"\r\n GPRINT:cdefb:MIN:min=%.2lf\r\n GPRINT:cdefb:AVERAGE:avg=%.2lf\r\n GPRINT:cdefb:MAX:"max=%.2lf\\l" \r\n LINE:bw#6666CC:"5 min avg Warning Threshold"\r\n GPRINT:bw:LAST:"%.1lf"\r\n LINE:bc#CC0000:"5 min avg Critical Threshold"\r\n GPRINT:bc:LAST:"%.1lf\\l"\r\n LINE3:cdefc#999999:"Fifteen Minute Load Average"   \r\n GPRINT:cdefc:MIN:min=%.2lf\r\n GPRINT:cdefc:AVERAGE:avg=%.2lf \r\n GPRINT:cdefc:MAX:"max=%.2lf\\l" \r\n LINE:cw#CCCC99:"15 min avg Warning Threshold"\r\n GPRINT:cw:LAST:"%.1lf"\r\n LINE:cc#990000:"15 min avg Critical Threshold"\r\n GPRINT:cc:LAST:"%.1lf\\l"\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120'		 
16	*	local_mem	nagios	1	0	1	Memory Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE \r\n DEF:w="rrd_source":ds_source_1:AVERAGE \r\n DEF:c="rrd_source":ds_source_2:AVERAGE \r\n CDEF:cdefa=a\r\n CDEF:cdefb=a,0.99,* \r\n CDEF:cdefw=w \r\n CDEF:cdefc=c \r\n CDEF:cdefm=c,1.05,*\r\n AREA:a#33FFFF \r\n AREA:cdefb#3399FF:"Memory Utilized\\:" \r\n GPRINT:a:LAST:"%.2lf Percent"\r\n GPRINT:cdefa:MIN:min=%.2lf\r\n GPRINT:cdefa:AVERAGE:avg=%.2lf\r\n GPRINT:cdefa:MAX:max="%.2lf\\l" \r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:" \r\n GPRINT:cdefw:LAST:"%.2lf" \r\n LINE2:cdefc#FF0033:"Critical Threshold\\:" \r\n GPRINT:cdefc:LAST:"%.2lf\\l"  \r\n COMMENT:"Service\\: SERVICE"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -u 100 -l 0 --rigid'		([\\d\\.]+)%
17	*	local_mysql_engine	nagios	1	1	1	MySQL Queries Per Second	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	/graphs/cgi-bin/number_graph.cgi	 	Queries per second avg: ([\\d\\.]+)
18	*	local_process	nagios	1	1	1	Process Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	'rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:"Number of Processes" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0'		(\\d+) process
19	*	local_nagios_latency	nagios	1	0	0	Nagios Service Check Latency in Seconds	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:min:GAUGE:1800:U:U DS:max:GAUGE:1800:U:U DS:avg:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE \r\n DEF:b="rrd_source":ds_source_1:AVERAGE \r\n DEF:c="rrd_source":ds_source_2:AVERAGE \r\n CDEF:cdefa=a\r\n CDEF:cdefb=b  \r\n CDEF:cdefc=c \r\n AREA:cdefb#66FFFF:"Maximum Latency\\: "\r\n GPRINT:cdefb:LAST:"%.2lf sec"\r\n GPRINT:cdefb:MIN:min=%.2lf \r\n GPRINT:cdefb:AVERAGE:avg=%.2lf   \r\n GPRINT:cdefb:MAX:max="%.2lf\\l" \r\n LINE:cdefb#999999\r\n AREA:cdefc#006699:"Average Latency\\: " \r\n GPRINT:c:LAST:"%.2lf sec"\r\n GPRINT:cdefc:MIN:min=%.2lf \r\n GPRINT:cdefc:AVERAGE:avg=%.2lf   \r\n GPRINT:cdefc:MAX:max="%.2lf\\l"  \r\n LINE:cdefc#999999\r\n AREA:a#333366:"Minimum Latency\\: " \r\n GPRINT:a:LAST:"%.2lf sec"\r\n GPRINT:cdefa:MIN:min=%.2lf \r\n GPRINT:cdefa:AVERAGE:avg=%.2lf   \r\n GPRINT:cdefa:MAX:max="%.2lf\\l" \r\n LINE:cdefa#999999 \r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0'		 
21	*	tcp_http	nagios	1	0	0	HTTP Response Time	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:$LABEL1$:GAUGE:1800:U:U DS:$LABEL1$_wn:GAUGE:1800:U:U DS:$LABEL1$_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE\r\n DEF:w="rrd_source":ds_source_1:AVERAGE\r\n DEF:c="rrd_source":ds_source_2:AVERAGE\r\n CDEF:cdefa=a CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w\r\n CDEF:cdefc=c \r\n AREA:a#33FFFF\r\n AREA:cdefb#00CF00:"Response Time\\:"\r\n GPRINT:a:LAST:"%.4lf Seconds"  \r\n GPRINT:a:MIN:min=%.2lf\r\n GPRINT:a:AVERAGE:avg=%.2lf\r\n GPRINT:a:MAX:max="%.2lf\\l"\r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:"\r\n GPRINT:cdefw:LAST:"%.2lf"\r\n LINE2:cdefc#FF0033:"Critical Threshold\\:"\r\n GPRINT:cdefc:LAST:"%.2lf\\l"  \r\n COMMENT:"Host\\: HOST\\l" COMMENT:"Service\\: SERVICE"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0'		 
22	*	local_mysql_database	nagios	1	1	1	MySQL Threads and Query Stats	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:threads:GAUGE:1800:U:U DS:slow_queries:COUNTER:1800:U:U DS:queries_per_sec:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$ 2>&1	'rrdtool graph - \r\n $LISTSTART$ \r\n   DEF:$DEFLABEL#$:AVERAGE \r\n   CDEF:cdef$CDEFLABEL#$=$CDEFLABEL#$\r\n   LINE2:$CDEFLABEL#$$COLORLABEL#$:$DSLABEL#$\r\n   GPRINT:$CDEFLABEL#$:MIN:min=%.2lf\r\n   GPRINT:$CDEFLABEL#$:AVERAGE:avg=%.2lf\r\n   GPRINT:$CDEFLABEL#$:MAX:max="%.2lf\\l"\r\n $LISTEND$\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120'		[\\S+|\\s+]+Threads: (\\d+)  [\\S+|\\s+]+queries: (\\d+)  [\\S+|\\s+]+  \\S+ [\\S+|\\s+]+avg: (\\d+\\.\\d+)
28	*	DEFAULT	nagios	1	0	0	DO NOT REMOVE THIS ENTRY - USE TO DEFINE DEFAULT GRAPHING SETTINGS				rrdtool graph - $LISTSTART$ DEF:$DEFLABEL#$:AVERAGE CDEF:cdef$CDEFLABEL#$=$CDEFLABEL#$ LINE2:$CDEFLABEL#$$COLORLABEL#$:$DSLABEL#$ GPRINT:$CDEFLABEL#$:MIN:min=%.2lf GPRINT:$CDEFLABEL#$:AVERAGE:avg=%.2lf GPRINT:$CDEFLABEL#$:MAX:max=%.2lf  $LISTEND$  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120		
29	*	local_users	nagios	1	0	0	Current Users	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:$LABEL1$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE  CDEF:cdefa=a  AREA:cdefa#0033CC:"Number of logged in users" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120		
30	*	local_cpu	nagios	1	0	1	CPU Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE \r\n DEF:w="rrd_source":ds_source_1:AVERAGE \r\n DEF:c="rrd_source":ds_source_2:AVERAGE \r\n CDEF:cdefa=a \r\n CDEF:cdefb=a,0.99,* \r\n AREA:cdefa#7D1B7E:"Process CPU Utilization" \r\n GPRINT:cdefa:LAST:Current=%.2lf \r\n GPRINT:cdefa:MIN:min=%.2lf \r\n GPRINT:cdefa:AVERAGE:avg=%.2lf \r\n GPRINT:cdefa:MAX:max="%.2lf\\l" \r\n AREA:cdefb#571B7E: \r\n CDEF:cdefw=w\r\n CDEF:cdefc=c \r\n CDEF:cdefm=cdefc,1.01,* \r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:" \r\n GPRINT:cdefw:LAST:"%.2lf" \r\n LINE2:cdefc#FF0033:"Critical Threshold\\:" \r\n GPRINT:cdefc:LAST:"%.2lf\\l" \r\n COMMENT:"Service\\: SERVICE"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 --rigid -u 100 -l 0'		
68	*	tcp_nsca	nagios	1	0	0	NSCA Response Time	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE\r\n DEF:w="rrd_source":ds_source_1:AVERAGE\r\n DEF:c="rrd_source":ds_source_2:AVERAGE\r\n CDEF:cdefa=a CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w CDEF:cdefc=c\r\n AREA:a#33FFFF AREA:cdefb#00CF00:"Response Time\\:"\r\n GPRINT:a:LAST:"%.4lf Seconds"  \r\n GPRINT:a:MIN:min=%.4lf\r\n GPRINT:a:AVERAGE:avg=%.4lf\r\n GPRINT:a:MAX:max="%.4lf\\l"\r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:"\r\n GPRINT:cdefw:LAST:"%.2lf"\r\n LINE2:cdefc#FF0033:"Critical Threshold\\:"\r\n GPRINT:cdefc:LAST:"%.2lf\\l"  \r\n COMMENT:"Host\\: HOST\\l" COMMENT:"Service\\: SERVICE"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0'		 
69	*	local_swap	nagios	1	0	0	Swap Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480\r\n	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE \r\n DEF:w="rrd_source":ds_source_1:AVERAGE \r\n DEF:c="rrd_source":ds_source_2:AVERAGE \r\n DEF:m="rrd_source":ds_source_3:AVERAGE \r\n CDEF:cdefa=a,m,/,100,* \r\n CDEF:cdefw=w\r\n CDEF:cdefc=c\r\n CDEF:cdefm=m \r\n AREA:a#9900FF:"Swap Free\\: " \r\n LINE2:a#6600FF: \r\n GPRINT:a:LAST:"%.2lf MB\\l" \r\n CDEF:cdefws=a,cdefw,LT,a,0,IF\r\n AREA:cdefws#FFFF00\r\n CDEF:cdefcs=a,cdefc,LT,a,0,IF\r\n AREA:cdefcs#FF0033 \r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:" \r\n GPRINT:cdefw:AVERAGE:"%.2lf" \r\n LINE2:cdefc#FF0033:"Critical Threshold\\:" \r\n GPRINT:cdefc:AVERAGE:"%.2lf\\l" \r\n GPRINT:cdefa:AVERAGE:"Percentage Swap Free"=%.2lf \r\n GPRINT:cdefm:AVERAGE:"Total Swap Space=%.2lf" \r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0'		
77	*	tcp_gw_listener	nagios	1	0	0	Foundation Listener Response Time	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:$LABEL1$:GAUGE:1800:U:U DS:$LABEL1$_wn:GAUGE:1800:U:U DS:$LABEL1$_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	'rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE\r\n DEF:w="rrd_source":ds_source_1:AVERAGE\r\n DEF:c="rrd_source":ds_source_2:AVERAGE\r\n CDEF:cdefa=a CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w\r\n CDEF:cdefc=c \r\n AREA:a#33FFFF\r\n AREA:cdefb#00CF00:"Response Time\\:"\r\n GPRINT:a:LAST:"%.4lf Seconds"  \r\n GPRINT:a:MIN:min=%.2lf\r\n GPRINT:a:AVERAGE:avg=%.2lf\r\n GPRINT:a:MAX:max="%.2lf\\l"\r\n LINE2:cdefw#FFFF00:"Warning Threshold\\:"\r\n GPRINT:cdefw:LAST:"%.2lf"\r\n LINE2:cdefc#FF0033:"Critical Threshold\\:"\r\n GPRINT:cdefc:LAST:"%.2lf\\l"  \r\n COMMENT:"Host\\: HOST\\l" COMMENT:"Service\\: SERVICE"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0'		 
78	*	^.+\\..+	nagios	1	\N	1	Collector Metric	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.99:1:8640 RRA:AVERAGE:0.99:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - \r\n DEF:a="rrd_source":ds_source_0:AVERAGE \r\n CDEF:cdefa=a \r\n AREA:cdefa#0000FF:"Collector Metric" \r\n GPRINT:cdefa:MIN:min=%.2lf \r\n GPRINT:cdefa:AVERAGE:avg=%.2lf \r\n GPRINT:cdefa:MAX:max=%.2lf \r\n -c BACK#FFFFFF \r\n -c CANVAS#FFFFFF \r\n -c GRID#C0C0C0 \r\n -c MGRID#404040 \r\n -c ARROW#FFFFFF \r\n -Y --height 120 -l 0		 
80	*	gdma_poller	nagios	1	\N	\N	GDMA Poller Performance	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U  $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$:$VALUE4$ 2>&1	'rrdtool graph - DEF:a="rrd_source":NumChecks:AVERAGE CDEF:cdefa=a LINE2:a#FF0033:NumChecks DEF:b="rrd_source":TimeSecs:AVERAGE CDEF:cdefb=b LINE2:b#33CC00:TimeSecs DEF:c="rrd_source":PctTime:AVERAGE CDEF:cdefc=c LINE2:c#3366FF:PctTime -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120'	 	 
81	*	gdma_spooler	nagios	1	\N	\N	GDMA Spooler Performance	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U  $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$ 2>&1	''	 	 
82	*	aix_swap	nagios	1	\N	\N	Swap Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE DEF:m="rrd_source":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#9900FF:"Swap Free\\: " LINE2:a#6600FF: GPRINT:a:LAST:"%.2lf MB\\l" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:AVERAGE:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:AVERAGE:"%.2lf\\l" GPRINT:cdefa:AVERAGE:"Percentage Swap Free"=%.2lf GPRINT:cdefm:AVERAGE:"Total Swap Space=%.2lf" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0	 	 
83	*	aix_disk	nagios	1	\N	1	Disk Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE DEF:m="rrd_source":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#C35617:"Space Used\\: " LINE:cdefa#FFCC00: GPRINT:a:LAST:"%.2lf MB\\l" LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:AVERAGE:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:AVERAGE:"%.2lf\\l" GPRINT:cdefa:AVERAGE:"Percentage Space Used"=%.2lf GPRINT:cdefm:AVERAGE:"Maximum Capacity"=%.2lf CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0	 	 
84	*	aix_load	nagios	1	\N	\N	Load Averages	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE3$:$WARN3$:$CRIT3$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE DEF:aw="rrd_source":ds_source_1:AVERAGE DEF:ac="rrd_source":ds_source_2:AVERAGE DEF:b=rrd_source:ds_source_3:AVERAGE DEF:bw="rrd_source":ds_source_4:AVERAGE DEF:bc="rrd_source":ds_source_5:AVERAGE DEF:c=rrd_source:ds_source_6:AVERAGE DEF:cw="rrd_source":ds_source_7:AVERAGE DEF:cc="rrd_source":ds_source_8:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:"One Minute Load Average" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:"max=%.2lf\\l" LINE:aw#FFCC33:"1 min avg Warning Threshold" GPRINT:aw:LAST:"%.1lf" LINE:ac#FF0000:"1 min avg Critical Threshold" GPRINT:ac:LAST:"%.1lf\\l" LINE2:cdefb#3300FF:"Five Minute Load Average" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:"max=%.2lf\\l" LINE:bw#6666CC:"5 min avg Warning Threshold" GPRINT:bw:LAST:"%.1lf" LINE:bc#CC0000:"5 min avg Critical Threshold" GPRINT:bc:LAST:"%.1lf\\l" LINE3:cdefc#999999:"Fifteen Minute Load Average" GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:"max=%.2lf\\l" LINE:cw#CCCC99:"15 min avg Warning Threshold" GPRINT:cw:LAST:"%.1lf" LINE:cc#990000:"15 min avg Critical Threshold" GPRINT:cc:LAST:"%.1lf\\l" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
85	*	aix_process_count	nagios	1	1	\N	Process Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:"Number of Processes" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0	 	(\\d+) process
86	*	linux_mem	nagios	1	\N	\N	Memory Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE CDEF:cdefa=a CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=c,1.05,* AREA:a#33FFFF AREA:cdefb#3399FF:"Memory Free\\:" GPRINT:a:LAST:"%.2lf Percent" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max="%.2lf\\l" LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:LAST:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:LAST:"%.2lf\\l" COMMENT:"Service\\: SERVICE" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -u 100 -l 0 --rigid	 	([\\d\\.]+)%
87	*	linux_process_count	nagios	1	1	\N	Process Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:"Number of Processes" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0	 	(\\d+) process
88	*	linux_swap	nagios	1	\N	\N	Swap Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE DEF:m="rrd_source":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#9900FF:"Swap Free\\: " LINE2:a#6600FF: GPRINT:a:LAST:"%.2lf MB\\l" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:AVERAGE:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:AVERAGE:"%.2lf\\l" GPRINT:cdefa:AVERAGE:"Percentage Swap Free"=%.2lf GPRINT:cdefm:AVERAGE:"Total Swap Space=%.2lf" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0	 	 
89	*	linux_disk	nagios	1	\N	1	Disk Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE DEF:m="rrd_source":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#C35617:"Space Used\\: " LINE:cdefa#FFCC00: GPRINT:a:LAST:"%.2lf MB\\l" LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:AVERAGE:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:AVERAGE:"%.2lf\\l" GPRINT:cdefa:AVERAGE:"Percentage Space Used"=%.2lf GPRINT:cdefm:AVERAGE:"Maximum Capacity"=%.2lf CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  -l 0	 	 
90	*	linux_load	nagios	1	\N	\N	Load Averages	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE3$:$WARN3$:$CRIT3$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE DEF:aw="rrd_source":ds_source_1:AVERAGE DEF:ac="rrd_source":ds_source_2:AVERAGE DEF:b=rrd_source:ds_source_3:AVERAGE DEF:bw="rrd_source":ds_source_4:AVERAGE DEF:bc="rrd_source":ds_source_5:AVERAGE DEF:c=rrd_source:ds_source_6:AVERAGE DEF:cw="rrd_source":ds_source_7:AVERAGE DEF:cc="rrd_source":ds_source_8:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:"One Minute Load Average" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:"max=%.2lf\\l" LINE:aw#FFCC33:"1 min avg Warning Threshold" GPRINT:aw:LAST:"%.1lf" LINE:ac#FF0000:"1 min avg Critical Threshold" GPRINT:ac:LAST:"%.1lf\\l" LINE2:cdefb#3300FF:"Five Minute Load Average" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:"max=%.2lf\\l" LINE:bw#6666CC:"5 min avg Warning Threshold" GPRINT:bw:LAST:"%.1lf" LINE:bc#CC0000:"5 min avg Critical Threshold" GPRINT:bc:LAST:"%.1lf\\l" LINE3:cdefc#999999:"Fifteen Minute Load Average" GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:"max=%.2lf\\l" LINE:cw#CCCC99:"15 min avg Warning Threshold" GPRINT:cw:LAST:"%.1lf" LINE:cc#990000:"15 min avg Critical Threshold" GPRINT:cc:LAST:"%.1lf\\l" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
91	*	solaris_disk	nagios	1	\N	1	Disk Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE DEF:m="rrd_source":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefb=a,0.99,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#C35617:"Space Used\\: " LINE:cdefa#FFCC00: GPRINT:a:LAST:"%.2lf MB\\l" LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:AVERAGE:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:AVERAGE:"%.2lf\\l" GPRINT:cdefa:AVERAGE:"Percentage Space Used"=%.2lf GPRINT:cdefm:AVERAGE:"Maximum Capacity"=%.2lf CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033 -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  -l 0	 	 
92	*	solaris_load	nagios	1	\N	\N	Load Averages	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE3$:$WARN3$:$CRIT3$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE DEF:aw="rrd_source":ds_source_1:AVERAGE DEF:ac="rrd_source":ds_source_2:AVERAGE DEF:b=rrd_source:ds_source_3:AVERAGE DEF:bw="rrd_source":ds_source_4:AVERAGE DEF:bc="rrd_source":ds_source_5:AVERAGE DEF:c=rrd_source:ds_source_6:AVERAGE DEF:cw="rrd_source":ds_source_7:AVERAGE DEF:cc="rrd_source":ds_source_8:AVERAGE CDEF:cdefa=a CDEF:cdefb=b CDEF:cdefc=c AREA:cdefa#FF6600:"One Minute Load Average" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:"max=%.2lf\\l" LINE:aw#FFCC33:"1 min avg Warning Threshold" GPRINT:aw:LAST:"%.1lf" LINE:ac#FF0000:"1 min avg Critical Threshold" GPRINT:ac:LAST:"%.1lf\\l" LINE2:cdefb#3300FF:"Five Minute Load Average" GPRINT:cdefb:MIN:min=%.2lf GPRINT:cdefb:AVERAGE:avg=%.2lf GPRINT:cdefb:MAX:"max=%.2lf\\l" LINE:bw#6666CC:"5 min avg Warning Threshold" GPRINT:bw:LAST:"%.1lf" LINE:bc#CC0000:"5 min avg Critical Threshold" GPRINT:bc:LAST:"%.1lf\\l" LINE3:cdefc#999999:"Fifteen Minute Load Average" GPRINT:cdefc:MIN:min=%.2lf GPRINT:cdefc:AVERAGE:avg=%.2lf GPRINT:cdefc:MAX:"max=%.2lf\\l" LINE:cw#CCCC99:"15 min avg Warning Threshold" GPRINT:cw:LAST:"%.1lf" LINE:cc#990000:"15 min avg Critical Threshold" GPRINT:cc:LAST:"%.1lf\\l" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
93	*	solaris_process_count	nagios	1	1	\N	Process Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:"Number of Processes" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0	 	(\\d+) process
94	*	solaris_swap	nagios	1	\N	\N	Swap Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE DEF:w="rrd_source":ds_source_1:AVERAGE DEF:c="rrd_source":ds_source_2:AVERAGE DEF:m="rrd_source":ds_source_3:AVERAGE CDEF:cdefa=a,m,/,100,* CDEF:cdefw=w CDEF:cdefc=c CDEF:cdefm=m AREA:a#9900FF:"Swap Free\\: " LINE2:a#6600FF: GPRINT:a:LAST:"%.2lf MB\\l" CDEF:cdefws=a,cdefw,LT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,LT,a,0,IF AREA:cdefcs#FF0033 LINE2:cdefw#FFFF00:"Warning Threshold\\:" GPRINT:cdefw:AVERAGE:"%.2lf" LINE2:cdefc#FF0033:"Critical Threshold\\:" GPRINT:cdefc:AVERAGE:"%.2lf\\l" GPRINT:cdefa:AVERAGE:"Percentage Swap Free"=%.2lf GPRINT:cdefm:AVERAGE:"Total Swap Space=%.2lf" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0	 	 
95	*	gdma_21_wmi_cpu	nagios	1	\N	\N	CPU Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	''	 	CPU Utilization ([\\d\\.]+)%
96	*	gdma_21_wmi_disktransfers	nagios	1	\N	\N	Disk Transfers Per Second	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:transferspersec:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	''	 	 
97	*	gdma_21_wmi_mem	nagios	1	\N	\N	Memory Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	''	 	Memory Utilization ([\\d\\.]+)%
98	*	gdma_21_wmi_disk_	nagios	1	\N	1	Disk Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:percent:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	''	 	Disk Utilization ([\\d\\.]+)%
99	*	gdma_21_wmi_memory_pages	nagios	1	\N	\N	Memory Pages Per Second	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:pagespersec:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	/	 	 
100	*	-(collisionCount|receive(Bytes|.+Error|Drops|Errors|Packets)|transmit(Bytes|Drops|Errors|Packets))$	nagios	1	\N	1	Open Daylight Service	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.99:1:8640 RRA:AVERAGE:0.99:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - \n DEF:a="rrd_source":ds_source_0:AVERAGE \n CDEF:cdefa=a \n AREA:cdefa#0000FF:"Network Switch Attribute" \n GPRINT:cdefa:MIN:min=%.2lf \n GPRINT:cdefa:AVERAGE:avg=%.2lf \n GPRINT:cdefa:MAX:max=%.2lf \n -c BACK#FFFFFF \n -c CANVAS#FFFFFF \n -c GRID#C0C0C0 \n -c MGRID#404040 \n -c ARROW#FFFFFF \n -Y --height 120 -l 0		 
101	*	RDS.	nagios	1	0	1	AWS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
102	*	EC2.	nagios	1	0	1	AWS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
103	*	EBS.	nagios	1	0	1	AWS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
104	*	memory	nagios'	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
105	*	memory-actual	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
106	*	memory-rss	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
107	*	syn(.)cpu	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
108	*	tap(.+)_rx	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
109	*	tap(.+)_rx_drop	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
110	*	tap(.+)_rx_errors	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
111	*	tap(.+)_rx_packets	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
112	*	tap(.+)_tx	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
113	*	tap(.+)_tx_drop	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
114	*	tap(.+)_tx_errors	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
115	*	tap(.+)_tx_packets	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
116	*	vd(.)_read	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
117	*	vd(.)_read_req	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
118	*	vd(.)_write	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
119	*	vd(.)_write_req	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
120	*	cpu(.)_time	nagios	1	0	1	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
121	*	free_disk_gb	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
122	*	free_ram_mb	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
123	*	running_vms	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
124	*	cpu_util	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
125	*	disk.read.bytes	nagios	1	0	0	OS	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
126	*	summary.quick	nagios	1	0	1	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
127	*	syn.host	nagios	1	0	1	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
128	*	perfcounter.	nagios	1	0	1	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
129	*	summary.runtime	nagios	1	0	1	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
130	*	summary.storage	nagios	1	0	1	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
131	*	syn.vm.	nagios	1	0	1	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
132	*	summary.capacity	nagios	1	0	0	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
133	*	summary.freeSpace	nagios	1	0	0	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
134	*	summary.uncommitted	nagios	1	0	0	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
135	*	syn.storage.percent.used	nagios	1	0	0	VM	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
136	*	aggr-raid-attributes.disk-count	nagios	1	0	0	NetApp Aggr Raid Disk Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
137	*	aggr-space-attributes.percent-used-capacity	nagios	1	0	0	NetApp Aggr Space % Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
138	*	aggr-space-attributes.size-available	nagios	1	0	0	NetApp Aggr Space Available	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
139	*	aggr-space-attributes.size-total	nagios	1	0	0	NetApp Aggr Space Total	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
140	*	aggr-space-attributes.size-used	nagios	1	0	0	NetApp Aggr Space Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
141	*	aggr-volume-count-attributes.flexvol-count	nagios	1	0	0	NetApp Aggr FlexVol Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
142	*	syn.aggregate.gb.available	nagios	1	0	0	NetApp Aggr GB Available	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
143	*	syn.aggregate.gb.used	nagios	1	0	0	NetApp Aggr GB Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
144	*	syn.volume.gb.available	nagios	1	0	0	NetApp Volume GB Available	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
145	*	syn.volume.gb.used	nagios	1	0	0	NetApp Volume GB Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
146	*	syn.volume.percent.bytes.used	nagios	1	0	0	NetApp Volume % Bytes Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
147	*	syn.volume.percent.files.used	nagios	1	0	0	NetApp Volume % Files Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
148	*	volume-inode-attributes.files-total	nagios	1	0	0	NetApp Inodes Total	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
149	*	volume-inode-attributes.files-used	nagios	1	0	0	NetApp Inodes Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
150	*	volume-space-attributes.percentage-size-used	nagios	1	0	0	NetApp Space % Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
151	*	volume-space-attributes.size-available	nagios	1	0	0	NetApp Space Available	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
152	*	volume-space-attributes.size-total	nagios	1	0	0	NetApp Space Total	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
153	*	volume-space-attributes.size-used	nagios	1	0	0	NetApp Space Used	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
154	*	computed-failed-disks	nagios	1	0	0	NetApp Failed Disks	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
155	*	cpu-busytime	nagios	1	0	0	NetApp CPU Busy Time	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
156	*	env-failed-fan-count	nagios	1	0	0	NetApp Failed Fan Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
157	*	env-failed-power-supply-count	nagios	1	0	0	NetApp Failed Power Supply Count	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
158	*	env-over-temperature	nagios	1	0	0	NetApp Over Temperature	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
159	*	node-uptime	nagios	1	0	0	NetApp Node Uptime	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
160	*	nvram-battery-status	nagios	1	0	0	NetApp NVRAM Battery Status	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
161	*	syn.cpu-controller-usage	nagios	1	0	0	NetApp CPU Controller % Usage	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	''	''	''
162	*	gdma_21_wmi_uptime	nagios	1	1	0	Windows Uptime	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:"Uptime in seconds" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0		(\\d+)
163	*	linux_uptime	nagios	1	1	0	Linux Uptime	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 600 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - DEF:a="rrd_source":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:"Uptime in seconds" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0		(\\d+)
164	*	windows_time_sync	nagios	1	0	1	Time Sync on Windows	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:DiffSec:GAUGE:1800:U:U DS:DiffSec_wn:GAUGE:1800:U:U DS:DiffSec_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode \n DEF:a=rrd_source:ds_source_0:AVERAGE \n DEF:aw="rrd_source":ds_source_1:AVERAGE\n DEF:ac="rrd_source":ds_source_2:AVERAGE\n CDEF:cdefa=a \n AREA:a#33FFFF:"Seconds Difference from Time Source" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf  \n GPRINT:cdefa:MAX:"max=%.2lf\\l"\n LINE:aw#FFCC33:"Warning Threshold" \n GPRINT:aw:LAST:"%.1lf"\n LINE:ac#FF0000:"Critical Threshold"\n GPRINT:ac:LAST:"%.1lf\\l"\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
165	*	windows_net	nagios	1	0	0	Windows Network Utilization	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr \n DS:S_Utilisation:GAUGE:1800:U:U \n DS:S_Utilisation_wn:GAUGE:1800:U:U \n DS:S_Utilisation_cr:GAUGE:1800:U:U \n DS:R_Utilization:GAUGE:1800:U:U  \n RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE4$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode \n DEF:a=rrd_source:ds_source_0:AVERAGE \n DEF:b=rrd_source:ds_source_3:AVERAGE\n CDEF:cdefa=a \n CDEF:cdefb=b\n AREA:a#AAFF44:"Send Bandwidth Percent" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf  \n GPRINT:cdefa:MAX:"max=%.2lf\\l"\n STACK:b#BB33FF:"Receive Bandwidth Percent" GPRINT:cdefb:MIN:min=%.2lf  GPRINT:cdefb:AVERAGE:avg=%.2lf  \n GPRINT:cdefb:MAX:"max=%.2lf\\l"\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  --height 120	 	 
166	*	windows_mem	nagios	1	0	1	RAM use on Windows	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:Utilisation:GAUGE:1800:U:U DS:Utilisation_wn:GAUGE:1800:U:U DS:Utilisation_cr:GAUGE:1800:U:U DS:Memory:GAUGE:1800:U:U DS:Memory_wn:GAUGE:1800:U:U DS:Memory_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode \n DEF:a=rrd_source:ds_source_0:AVERAGE \n DEF:aw="rrd_source":ds_source_1:AVERAGE\n DEF:ac="rrd_source":ds_source_2:AVERAGE\n DEF:z=rrd_source:ds_source_3:AVERAGE\n CDEF:cdefa=a \n CDEF:cdefz=z\n AREA:a#33FFFF:"RAM Utilization Percent" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf  \n GPRINT:cdefa:MAX:"max=%.2lf\\l"\n LINE:aw#FFCC33:"Warning Threshold" \n GPRINT:aw:LAST:"%.1lf"\n LINE:ac#FF0000:"Critical Threshold"\n GPRINT:ac:LAST:"%.1lf\\l"\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
167	*	windows_eventlog	nagios	1	0	1	Windows events	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	rrdtool graph - \n DEF:a="rrd_source":ds_source_0:AVERAGE \n DEF:aw="rrd_source":ds_source_1:AVERAGE \n DEF:ac="rrd_source":ds_source_2:AVERAGE \n CDEF:cdefa=a \n AREA:cdefa#FF335B:"Number of Events" \n GPRINT:cdefa:MIN:min=%.2lf \n GPRINT:cdefa:AVERAGE:avg=%.2lf \n GPRINT:cdefa:MAX:max=%.2lf \n LINE:aw#FFCC33:"Warning Threshold" \n GPRINT:aw:LAST:"%.1lf"\n LINE:ac#FF0000:"Critical Threshold"\n GPRINT:ac:LAST:"%.1lf\\l"\n -c BACK#FFFFFF \n -c CANVAS#FFFFFF \n -c GRID#C0C0C0 \n -c MGRID#404040 \n -c ARROW#FFFFFF \n -Y --height 120 -l 0	 	 
168	*	windows_disks	nagios	1	0	0	Disk Space on Windows	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ --template $LABELLIST$ $LASTCHECK$:$VALUELIST$ 2>&1	rrdtool graph - \n$LISTSTART$ \nDEF:$DEFLABEL#$:AVERAGE \nCDEF:cdef$CDEFLABEL#$=$CDEFLABEL#$ \nLINE2:$CDEFLABEL#$$COLORLABEL#$:$DSLABEL#$ \n$LISTEND$  \n-c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
169	*	windows_disk_.	nagios	1	0	1	Disk Space on Windows	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:C_Utilisation:GAUGE:1800:U:U DS:C_Utilisation_wn:GAUGE:1800:U:U DS:C_Utilisation_cr:GAUGE:1800:U:U DS:C_Space:GAUGE:1800:U:U DS:C_Space_wn:GAUGE:1800:U:U DS:C_Space_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	rrdtool graph - --imgformat=PNG --slope-mode \n DEF:a=rrd_source:ds_source_0:AVERAGE \n DEF:aw="rrd_source":ds_source_1:AVERAGE\n DEF:ac="rrd_source":ds_source_2:AVERAGE\n DEF:z=rrd_source:ds_source_3:AVERAGE\n CDEF:cdefa=a \n CDEF:cdefz=z\n AREA:a#C956AA:"Disk Utilization Percent" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf  \n GPRINT:cdefa:MAX:"max=%.2lf\\l"\n LINE:aw#FFCC33:"Warning Threshold" \n GPRINT:aw:LAST:"%.1lf"\n LINE:ac#FF0000:"Critical Threshold"\n GPRINT:ac:LAST:"%.1lf\\l"\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120	 	 
170	*	windows_cpu_queue	nagios	1	0	0	CPU Queue on Windows	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:metric:GAUGE:1800:U:U RRA:AVERAGE:0.99:1:8640 RRA:AVERAGE:0.99:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1	rrdtool graph - \n DEF:a="rrd_source":ds_source_0:AVERAGE \n CDEF:cdefa=a \n AREA:cdefa#F000FF:"CPU Execution Queue" \n GPRINT:cdefa:MIN:min=%.2lf \n GPRINT:cdefa:AVERAGE:avg=%.2lf \n GPRINT:cdefa:MAX:max=%.2lf \n -c BACK#FFFFFF \n -c CANVAS#FFFFFF \n -c GRID#C0C0C0 \n -c MGRID#404040 \n -c ARROW#FFFFFF \n -Y --height 120 -l 0	 	 
171	*	windows_cpu	nagios	1	0	1	CPU Utilization on Windows	$HOST$_$SERVICE$.rrd	$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:AvgCPU:GAUGE:1800:U:U DS:AvgCPU_wn:GAUGE:1800:U:U DS:AvgCPU_cr:GAUGE:1800:U:U  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480	$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1	rrdtool graph - \n DEF:a="rrd_source":ds_source_0:AVERAGE \n DEF:w="rrd_source":ds_source_1:AVERAGE \n DEF:c="rrd_source":ds_source_2:AVERAGE \n CDEF:cdefa=a \n CDEF:cdefb=a,0.99,* \n AREA:cdefa#7D1B7E:"Percent CPU Utilization" \n GPRINT:cdefa:LAST:Current=%.2lf \n GPRINT:cdefa:MIN:min=%.2lf \n GPRINT:cdefa:AVERAGE:avg=%.2lf \n GPRINT:cdefa:MAX:max="%.2lf\\l" \n AREA:cdefb#571B7E: \n CDEF:cdefw=w\n CDEF:cdefc=c \n CDEF:cdefm=cdefc,1.01,* \n LINE2:cdefw#FFFF00:"Warning Threshold\\:" \n GPRINT:cdefw:LAST:"%.2lf" \n LINE2:cdefc#FF0033:"Critical Threshold\\:" \n GPRINT:cdefc:LAST:"%.2lf\\l" \n COMMENT:"Service\\: SERVICE"\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\n CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 --rigid -u 100 -l 0	 	 
\.


--
-- Name: performanceconfig_performanceconfig_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('performanceconfig_performanceconfig_id_seq', 171, true);


--
-- Data for Name: profile_host_profile_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY profile_host_profile_service (hostprofile_id, serviceprofile_id) FROM stdin;
3	2
2	3
1	4
4	5
5	6
6	7
7	8
8	9
\.


--
-- Data for Name: profile_hostgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY profile_hostgroup (hostprofile_id, hostgroup_id) FROM stdin;
\.


--
-- Data for Name: profile_parent; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY profile_parent (hostprofile_id, host_id) FROM stdin;
\.


--
-- Name: profiles_host_hostprofile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('profiles_host_hostprofile_id_seq', 8, true);


--
-- Name: profiles_service_serviceprofile_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('profiles_service_serviceprofile_id_seq', 12, true);


--
-- Data for Name: service_dependency; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY service_dependency (id, service_id, host_id, depend_on_host_id, template, comment) FROM stdin;
\.


--
-- Name: service_dependency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('service_dependency_id_seq', 1, false);


--
-- Data for Name: service_dependency_templates; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY service_dependency_templates (id, name, servicename_id, data, comment) FROM stdin;
\.


--
-- Name: service_dependency_templates_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('service_dependency_templates_id_seq', 1, false);


--
-- Data for Name: service_instance; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY service_instance (instance_id, service_id, name, status, arguments, externals_arguments, inherit_ext_args) FROM stdin;
\.


--
-- Name: service_instance_instance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('service_instance_instance_id_seq', 1, false);


--
-- Name: service_names_servicename_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('service_names_servicename_id_seq', 268, true);


--
-- Data for Name: service_overrides; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY service_overrides (service_id, check_period, notification_period, event_handler, data) FROM stdin;
\.


--
-- Name: service_templates_servicetemplate_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('service_templates_servicetemplate_id_seq', 2, true);


--
-- Data for Name: servicegroups; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY servicegroups (servicegroup_id, name, alias, escalation_id, comment, notes) FROM stdin;
\.


--
-- Data for Name: servicegroup_service; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY servicegroup_service (servicegroup_id, host_id, service_id) FROM stdin;
\.


--
-- Name: servicegroups_servicegroup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('servicegroups_servicegroup_id_seq', 1, false);


--
-- Data for Name: servicename_dependency; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY servicename_dependency (id, servicename_id, depend_on_host_id, template) FROM stdin;
\.


--
-- Name: servicename_dependency_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('servicename_dependency_id_seq', 1, false);


--
-- Data for Name: servicename_overrides; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY servicename_overrides (servicename_id, check_period, notification_period, event_handler, data) FROM stdin;
16	\N	\N	\N	<?xml version="1.0" ?>\n<data>\n </data>
233	1	\N	\N	<?xml version="1.0" encoding="iso-8859-1" ?>\n<data>\n  <prop name="active_checks_enabled"><![CDATA[-zero-]]>\n  </prop>\n  <prop name="max_check_attempts"><![CDATA[1]]>\n  </prop>\n</data>
\.


--
-- Data for Name: serviceprofile; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY serviceprofile (servicename_id, serviceprofile_id) FROM stdin;
169	2
13	3
14	3
15	3
16	3
6	4
6	5
233	5
238	6
237	6
234	6
239	6
236	6
235	6
240	7
238	7
241	7
245	7
239	7
243	7
244	7
242	7
246	8
238	8
248	8
239	8
249	8
247	8
238	9
252	9
251	9
239	9
253	9
250	9
254	9
256	9
255	9
257	10
258	10
259	11
260	11
261	12
262	12
263	12
264	12
265	12
266	12
267	12
268	12
\.


--
-- Data for Name: serviceprofile_host; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY serviceprofile_host (serviceprofile_id, host_id) FROM stdin;
\.


--
-- Data for Name: serviceprofile_hostgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY serviceprofile_hostgroup (serviceprofile_id, hostgroup_id) FROM stdin;
\.


--
-- Name: services_service_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('services_service_id_seq', 189, true);


--
-- Data for Name: sessions; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY sessions (id, a_session) FROM stdin;
\.


--
-- Data for Name: setup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY setup (name, type, value) FROM stdin;
accept_passive_host_checks	nagios	1
accept_passive_service_checks	nagios	1
ack_no_send	nagios_cgi	0
ack_no_sticky	nagios_cgi	0
additional_freshness_latency	nagios	15
admin_email	nagios	nagios@localhost
admin_pager	nagios	pagenagios@localhost
authorized_contactgroup_for_all_host_commands	nagios_cgi	\N
authorized_contactgroup_for_all_hosts	nagios_cgi	\N
authorized_contactgroup_for_all_service_commands	nagios_cgi	\N
authorized_contactgroup_for_all_services	nagios_cgi	\N
authorized_contactgroup_for_configuration_information	nagios_cgi	\N
authorized_contactgroup_for_read_only	nagios_cgi	\N
authorized_contactgroup_for_system_commands	nagios_cgi	\N
authorized_contactgroup_for_system_information	nagios_cgi	\N
authorized_for_all_host_commands	nagios_cgi	admin
authorized_for_all_hosts	nagios_cgi	admin,guest
authorized_for_all_service_commands	nagios_cgi	admin
authorized_for_all_services	nagios_cgi	admin,guest
authorized_for_configuration_information	nagios_cgi	admin,jdoe
authorized_for_read_only	nagios_cgi	\N
authorized_for_system_commands	nagios_cgi	admin
authorized_for_system_information	nagios_cgi	admin,theboss,jdoe
auto_reschedule_checks	nagios	\N
auto_rescheduling_interval	nagios	30
auto_rescheduling_window	nagios	180
backup_dir	config	/usr/local/groundwork/monarch/backup
broker_module	nagios	/usr/local/nagios/lib/libbronx.so
cached_host_check_horizon	nagios	15
cached_service_check_horizon	nagios	15
cgi_bin	config	0
check_external_commands	nagios	1
check_for_orphaned_hosts	nagios	1
check_for_orphaned_services	nagios	\N
check_host_freshness	nagios	\N
check_result_path	nagios	/usr/local/nagios/var/checkresults
check_result_reaper_frequency	nagios	10
check_service_freshness	nagios	1
child_processes_fork_twice	nagios	\N
command_check_interval	nagios	-1
command_file	nagios	/usr/local/nagios/var/spool/nagios.cmd
commands	file	26
contact_template	monarch_ez	generic-contact-2
contact_templates	file	29
contactgroup	monarch_ez	nagiosadmin
contactgroups	file	30
contacts	file	31
date_format	nagios	us
debug_file	nagios	/usr/local/nagios/var/nagios.debug
debug_level	nagios	0
debug_verbosity	nagios	1
default_statusmap_layout	nagios_cgi	5
default_statuswrl_layout	nagios_cgi	2
default_user_name	nagios_cgi	admin
doc_root	config	0
enable_environment_macros	nagios	\N
enable_event_handlers	nagios	1
enable_externals	config	1
enable_flap_detection	nagios	\N
enable_groups	config	0
enable_notifications	nagios	\N
enable_predictive_host_dependency_checks	nagios	1
enable_predictive_service_dependency_checks	nagios	1
escalation_templates	file	18
escalations	file	35
event_broker_options	nagios	-1
event_handler_timeout	nagios	30
execute_host_checks	nagios	1
execute_service_checks	nagios	1
extended_host_info	file	36
extended_host_info_templates	file	22
extended_service_info	file	21
extended_service_info_templates	file	20
external_command_buffer_slots	nagios	\N
free_child_process_memory	nagios	\N
global_host_event_handler	nagios	\N
global_service_event_handler	nagios	\N
high_host_flap_threshold	nagios	50.0
high_service_flap_threshold	nagios	50.0
host_check_timeout	nagios	30
host_dependencies	file	23
host_down_sound	nagios_cgi	\N
host_freshness_check_interval	nagios	60
host_inter_check_delay_method	nagios	s
host_perfdata_command	nagios	\N
host_perfdata_file	nagios	\N
host_perfdata_file_mode	nagios	w
host_perfdata_file_processing_command	nagios	\N
host_perfdata_file_processing_interval	nagios	\N
host_perfdata_file_template	nagios	\N
host_profile	monarch_ez	host-profile-service-ping
host_templates	file	32
host_unreachable_sound	nagios_cgi	\N
hostgroups	file	33
hosts	file	13
illegal_macro_output_chars	nagios	`~$&|"<>
illegal_object_name_chars	nagios	`~!$%^&*|'"<>?,()'=
interval_length	nagios	60
is_portal	config	1
lock_author_names	nagios_cgi	\N
lock_file	nagios	/var/run/nagios.lock
log_archive_path	nagios	/usr/local/nagios/var/archives
log_event_handlers	nagios	1
log_external_commands	nagios	1
log_file	nagios	/usr/local/nagios/var/nagios.log
log_host_retries	nagios	1
log_initial_states	nagios	\N
log_notifications	nagios	1
log_passive_checks	nagios	1
log_passive_service_checks	nagios	\N
log_rotation_method	nagios	d
log_service_retries	nagios	1
login_authentication		open
low_host_flap_threshold	nagios	25.0
low_service_flap_threshold	nagios	25.0
max_check_result_file_age	nagios	\N
max_check_result_reaper_time	nagios	\N
max_concurrent_checks	nagios	100
max_debug_file_size	nagios	1000000
max_host_check_spread	nagios	30
max_service_check_spread	nagios	30
max_tree_nodes	config	3000
max_unlocked_backups	config	10
misccommands	file	27
monarch_home	config	/usr/local/groundwork/monarch
monarch_version	config	4.6
nagios_bin	config	/usr/local/nagios/bin
nagios_etc	config	/usr/local/nagios/etc
nagios_group	nagios	nagios
nagios_user	nagios	nagios
nagios_version	config	3.x
normal_sound	nagios_cgi	\N
notification_timeout	nagios	30
object_cache_file	nagios	/usr/local/nagios/var/objects.cache
obsess_over_hosts	nagios	\N
obsess_over_services	nagios	\N
ochp_command	nagios	\N
ochp_timeout	nagios	5
ocsp_command	nagios	\N
ocsp_timeout	nagios	5
other_host_inter_check_delay_method	nagios	\N
other_service_inter_check_delay_method	nagios	\N
other_service_interleave_factor	nagios	\N
passive_host_checks_are_soft	nagios	\N
perfdata_timeout	nagios	60
perflogbug_workaround_removed	nagios	1
physical_html_path	nagios_cgi	/usr/local/nagios/share
ping_syntax	nagios_cgi	/bin/ping -n -U -c 5 $HOSTADDRESS$
precached_object_file	nagios	/usr/local/nagios/var/objects.precache
process_performance_data	nagios	1
refresh_rate	nagios_cgi	90
resource_file	nagios	/usr/local/nagios/etc/resource.cfg
resource_label1	resource	plugin directory
resource_label10	resource	
resource_label11	resource	
resource_label12	resource	
resource_label13	resource	sendEmail smtp mail relay option (-s) value
resource_label14	resource	
resource_label15	resource	
resource_label16	resource	
resource_label17	resource	default check_by_ssh remote user name for all SSH checks
resource_label18	resource	
resource_label19	resource	NSClient TCP Port
resource_label2	resource	event handler scripts directory
resource_label20	resource	
resource_label21	resource	GroundWork Proxy Server IP
resource_label22	resource	default plugin subdirectory on remote hosts, relative to the home directory of the user you SSH in as
resource_label23	resource	
resource_label24	resource	
resource_label25	resource	
resource_label26	resource	
resource_label27	resource	
resource_label28	resource	
resource_label29	resource	
resource_label3	resource	plugin timeout
resource_label30	resource	
resource_label31	resource	
resource_label32	resource	GroundWork Server fully qualified hostname
resource_label4	resource	NSClient password
resource_label5	resource	
resource_label6	resource	default MySQL password for GroundWork databases
resource_label7	resource	SNMP community string
resource_label8	resource	alternate SNMP community string
resource_label9	resource	
result_limit	nagios_cgi	75
retain_state_information	nagios	1
retained_contact_host_attribute_mask	nagios	0
retained_contact_service_attribute_mask	nagios	0
retained_host_attribute_mask	nagios	0
retained_process_host_attribute_mask	nagios	0
retained_process_service_attribute_mask	nagios	0
retained_service_attribute_mask	nagios	0
retention_update_interval	nagios	60
service_check_timeout	nagios	60
service_critical_sound	nagios_cgi	\N
service_dependency	file	17
service_dependency_templates	file	16
service_freshness_check_interval	nagios	60
service_inter_check_delay_method	nagios	s
service_interleave_factor	nagios	s
service_perfdata_command	nagios	\N
service_perfdata_file	nagios	/usr/local/nagios/var/service-perfdata.dat
service_perfdata_file_mode	nagios	a
service_perfdata_file_processing_command	nagios	launch_perfdata_process
service_perfdata_file_processing_interval	nagios	300
service_perfdata_file_template	nagios	$LASTSERVICECHECK$\\t$HOSTNAME$\\t$SERVICEDESC$\\t$SERVICEOUTPUT$\\t$SERVICEPERFDATA$
service_templates	file	34
service_unknown_sound	nagios_cgi	\N
service_warning_sound	nagios_cgi	\N
servicegroups	file	15
services	file	19
session_timeout		3600
show_context_help	nagios_cgi	1
sleep_time	nagios	1
soft_state_dependencies	nagios	\N
state_retention_file	nagios	/usr/local/nagios/var/nagiosstatus.sav
status_file	nagios	/usr/local/nagios/var/status.dat
status_update_interval	nagios	15
statusmap_background_image	nagios_cgi	states.png
statuswrl_include	nagios_cgi	myworld.wrl
super_user_password		
tac_cgi_hard_only	nagios_cgi	0
task	nagios	view_edit
temp_file	nagios	/usr/local/nagios/var/nagios.tmp
temp_path	nagios	/tmp
time_periods	file	28
translate_passive_host_checks	nagios	\N
upload_dir	config	/tmp
url_html_path	nagios_cgi	/nagios
use_aggressive_host_checking	nagios	\N
use_authentication	nagios_cgi	1
use_large_installation_tweaks	nagios	1
use_pending_states	nagios_cgi	1
use_regexp_matching	nagios	\N
use_retained_program_state	nagios	1
use_retained_scheduling_info	nagios	1
use_syslog	nagios	\N
use_timezone	nagios	
use_true_regexp_matching	nagios	\N
user1	resource	/usr/local/nagios/libexec
user10	resource	
user11	resource	
user12	resource	
user13	resource	127.0.0.1
user14	resource	
user15	resource	
user16	resource	
user17	resource	nagios
user18	resource	
user19	resource	1248
user2	resource	
user20	resource	
user21	resource	127.0.0.1
user22	resource	libexec
user23	resource	
user24	resource	
user25	resource	
user26	resource	
user27	resource	
user28	resource	
user29	resource	
user3	resource	60
user30	resource	
user31	resource	
user32	resource	USER32_GROUNDWORK_SERVER
user4	resource	somepassword
user5	resource	
user6	resource	gwrk
user7	resource	public
user8	resource	itgwrk
user9	resource	
website_url	nagios	\N
\.


--
-- Data for Name: stage_host_hostgroups; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY stage_host_hostgroups (name, user_acct, hostgroup) FROM stdin;
\.


--
-- Data for Name: stage_host_services; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY stage_host_services (name, user_acct, host, type, status, service_id) FROM stdin;
\.


--
-- Data for Name: stage_hosts; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY stage_hosts (name, user_acct, type, status, alias, address, os, hostprofile, serviceprofile, info, notes) FROM stdin;
\.


--
-- Data for Name: stage_other; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY stage_other (name, type, parent, data, comment) FROM stdin;
\.


--
-- Data for Name: time_period_exclude; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY time_period_exclude (timeperiod_id, exclude_id) FROM stdin;
\.


--
-- Data for Name: time_period_property; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY time_period_property (timeperiod_id, name, type, value, comment) FROM stdin;
2	friday	weekday	09:00-17:00	
2	monday	weekday	09:00-17:00	
2	thursday	weekday	09:00-17:00	
2	tuesday	weekday	09:00-17:00	
2	wednesday	weekday	09:00-17:00	
3	friday	weekday	00:00-24:00	
3	monday	weekday	00:00-24:00	
3	saturday	weekday	00:00-24:00	
3	sunday	weekday	00:00-24:00	
3	thursday	weekday	00:00-24:00	
3	tuesday	weekday	00:00-24:00	
3	wednesday	weekday	00:00-24:00	
4	friday	weekday	00:00-09:00,17:00-24:00	
4	monday	weekday	00:00-09:00,17:00-24:00	
4	saturday	weekday	00:00-24:00	
4	sunday	weekday	00:00-24:00	
4	thursday	weekday	00:00-09:00,17:00-24:00	
4	tuesday	weekday	00:00-09:00,17:00-24:00	
4	wednesday	weekday	00:00-09:00,17:00-24:00	
\.


--
-- Name: time_periods_timeperiod_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('time_periods_timeperiod_id_seq', 4, true);


--
-- Data for Name: tree_template_contactgroup; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY tree_template_contactgroup (tree_id, template_id, contactgroup_id) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY users (user_id, user_acct, user_name, password, session) FROM stdin;
1	super_user	Super User Account	Py.Z3VRXrRE3k	4ce50937286796d7a3ddcd978f0ea459
2	admin	admin		47cd4fa89c4fc37ba117dbf1fe8a7e7a
\.


--
-- Data for Name: user_group; Type: TABLE DATA; Schema: public; Owner: monarch
--

COPY user_group (usergroup_id, user_id) FROM stdin;
1	1
1	2
\.


--
-- Name: user_groups_usergroup_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('user_groups_usergroup_id_seq', 1, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: monarch
--

SELECT pg_catalog.setval('users_user_id_seq', 2, true);


--
-- PostgreSQL database dump complete
--

