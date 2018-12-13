--
-- Copyright 2007-2011 GroundWork Open Source, Inc. (GroundWork)
-- All rights reserved. This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License version 2 as published
-- by the Free Software Foundation.
--
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY
-- WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
-- PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License along with this
-- program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street,
-- Fifth Floor, Boston, MA 02110-1301, USA.
--
-- MySQL dump 10.11
--
-- Host: localhost    Database: monarch
-- ------------------------------------------------------
-- Server version	5.0.50sp1-enterprise

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `access_list`
--

DROP TABLE IF EXISTS `access_list`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `access_list` (
  `object` varchar(50) NOT NULL default '',
  `type` varchar(50) NOT NULL default '',
  `usergroup_id` smallint(4) unsigned NOT NULL default '0',
  `access_values` varchar(20) default NULL,
  PRIMARY KEY  (`object`,`type`,`usergroup_id`),
  KEY `usergroup_id` (`usergroup_id`),
  CONSTRAINT `access_list_ibfk_1` FOREIGN KEY (`usergroup_id`) REFERENCES `user_groups` (`usergroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `access_list`
--

LOCK TABLES `access_list` WRITE;
/*!40000 ALTER TABLE `access_list` DISABLE KEYS */;
INSERT INTO `access_list` VALUES
	('commands','design_manage',1,'add,modify,delete'),
	('commit','control',1,'full_control'),
	('contactgroups','design_manage',1,'add,modify,delete'),
	('contacts','design_manage',1,'add,modify,delete'),
	('contact_templates','design_manage',1,'add,modify,delete'),
	('escalations','design_manage',1,'add,modify,delete'),
	('export','design_manage',1,'add,modify,delete'),
	('extended_host_info_templates','design_manage',1,'add,modify,delete'),
	('extended_service_info_templates','design_manage',1,'add,modify,delete'),
	('externals','design_manage',1,'add,modify,delete'),
	('ez_commit','ez',1,'ez_commit'),
	('ez_discover','ez',1,'ez_discover'),
	('ez_enabled','ez',1,'ez_enabled'),
	('ez_hosts','ez',1,'ez_hosts'),
	('ez_host_groups','ez',1,'ez_host_groups'),
	('ez_import','ez',1,'ez_import'),
	('ez_notifications','ez',1,'ez_notifications'),
	('ez_profiles','ez',1,'ez_profiles'),
	('ez_setup','ez',1,'ez_setup'),
	('files','control',1,'full_control'),
	('hostgroups','design_manage',1,'add,modify,delete'),
	('hosts','design_manage',1,'add,modify,delete'),
	('host_delete_tool','tools',1,'add,modify,delete'),
	('host_dependencies','design_manage',1,'add,modify,delete'),
	('host_templates','design_manage',1,'add,modify,delete'),
	('import','discover',1,'full_control'),
	('load','control',1,'full_control'),
	('main_ez','ez',1,'main_ez'),
	('manage','group_macro',1,'manage'),
	('match_strings','discover',1,'full_control'),
	('nagios_cgi_configuration','control',1,'full_control'),
	('nagios_main_configuration','control',1,'full_control'),
	('nagios_resource_macros','control',1,'full_control'),
	('nmap','discover',1,'full_control'),
	('parent_child','design_manage',1,'add,modify,delete'),
	('pre_flight_test','control',1,'full_control'),
	('process_stage','discover',1,'full_control'),
	('profiles','design_manage',1,'add,modify,delete'),
	('run_external_scripts','control',1,'full_control'),
	('servicegroups','design_manage',1,'add,modify,delete'),
	('services','design_manage',1,'add,modify,delete'),
	('service_delete_tool','tools',1,'add,modify,delete'),
	('service_dependency_templates','design_manage',1,'add,modify,delete'),
	('service_templates','design_manage',1,'add,modify,delete'),
	('setup','control',1,'full_control'),
	('time_periods','design_manage',1,'add,modify,delete'),
	('users','control',1,'full_control'),
	('user_groups','control',1,'full_control');
/*!40000 ALTER TABLE `access_list` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `commands`
--

DROP TABLE IF EXISTS `commands`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `commands` (
  `command_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `type` varchar(50) default NULL,
  `data` text,
  `comment` text,
  PRIMARY KEY  (`command_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `commands`
--

LOCK TABLES `commands` WRITE;
/*!40000 ALTER TABLE `commands` DISABLE KEYS */;
INSERT INTO `commands` VALUES
	(1,'check_local_load','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_load -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>','# \'check_local_load\' command definition'),
	(2,'check_nntp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nntp -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>','# \'check_nntp\' command definition'),
	(3,'check_telnet','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 23]]>\n </prop>\n</data>','# \'check_telnet\' command definition'),
	(4,'check_ftp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_ftp -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>','# \'check_ftp\' command definition'),
	(5,'host-notify-by-email','notify','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"GroundWork Host Status Notification:\\n\\nType:        $NOTIFICATIONTYPE$\\nHost:        $HOSTNAME$ ($HOSTADDRESS$)\\nHost State:  $HOSTSTATE$\\nHost Info:   $HOSTOUTPUT$\\nTime:        $LONGDATETIME$\\nHost Notes:  `echo \'$HOSTNOTES$\' | sed \'s/<br>/\\\\n/g\'`\\n\" | /usr/bin/mail -s \"[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$\" $CONTACTEMAIL$]]>\n  </prop>\n</data>','# \'host-notify-by-email\' command definition'),
	(6,'process-service-perfdata','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"$LASTSERVICECHECK$\\t$HOSTNAME$\\t$SERVICEDESC$\\t$SERVICESTATE$\\t$SERVICEATTEMPT$\\t$SERVICESTATETYPE$\\t$SERVICEEXECUTIONTIME$\\t$SERVICELATENCY$\\t$SERVICEOUTPUT$\\t$SERVICEPERFDATA$\\n\" >> /usr/local/nagios/var/service-perfdata.dat]]>\n </prop>\n</data>','# \'process-service-perfdata\' command definition'),
	(7,'check-host-alive','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_icmp -H $HOSTADDRESS$ -w 3000.0,80% -c 5000.0,100% -n 1]]>\n  </prop>\n</data>','# \'check-host-alive\' command definition'),
	(8,'check_udp','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_udp -H $HOSTADDRESS$ -p $ARG1$]]>\n </prop>\n</data>','# \'check_udp\' command definition'),
	(9,'service-notify-by-epager','notify','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"Host $HOSTNAME$ is $HOSTSTATE$\\nService $SERVICEDESC$ is $SERVICESTATE$\\nInfo: $SERVICEOUTPUT$\\nTime: $LONGDATETIME$\\n\" | /usr/bin/mail -s \"$NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$\" $CONTACTPAGER$]]>\n  </prop>\n</data>','# \'notify-by-epager\' command definition'),
	(10,'check_local_procs','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_procs -w $ARG1$ -c $ARG2$ -s $ARG3$]]>\n </prop>\n</data>','# \'check_local_procs\' command definition'),
	(11,'check_http','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_http -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>','# \'check_http\' command definition'),
	(12,'check_pop3','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_pop -H $HOSTADDRESS$]]>\n </prop>\n</data>','# \'check_pop\' command definition'),
	(13,'check_hpjd','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_hpjd -H $HOSTADDRESS$ -C public]]>\n </prop>\n</data>','# \'check_hpjd\' command definition'),
	(14,'service-notify-by-email','notify','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"GroundWork Service Status Notification:\\n\\nType:           $NOTIFICATIONTYPE$\\nHost:           $HOSTNAME$ ($HOSTADDRESS$)\\nHost State:     $HOSTSTATE$\\nService:        $SERVICEDESC$\\nService State:  $SERVICESTATE$\\nService Info:   $SERVICEOUTPUT$\\nTime:           $LONGDATETIME$\\nService Notes:  `echo \'$SERVICENOTES$\' | sed \'s/<br>/\\\\n/g\'`\\n\" | /usr/bin/mail -s \"[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$\" $CONTACTEMAIL$]]>\n  </prop>\n</data>','# \'notify-by-email\' command definition'),
	(15,'check_smtp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_smtp -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>','# \'check_smtp\' command definition'),
	(16,'check_local_users','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_users -w $ARG1$ -c $ARG2$]]>\n </prop>\n</data>','# \'check_local_users\' command definition'),
	(17,'host-notify-by-epager','notify','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"Host $HOSTNAME$ is $HOSTSTATE$\\nInfo: $HOSTOUTPUT$\\nTime: $LONGDATETIME$\\n\" | /usr/bin/mail -s \"$NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$\" $CONTACTPAGER$]]>\n  </prop>\n</data>','# \'host-notify-by-epager\' command definition'),
	(18,'check_proc','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_procs -c $ARG1$ -C $ARG2$]]>\n </prop>\n</data>','# \'check_procs\' command definition'),
	(19,'check_ping','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[$USER1$/check_icmp -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$ -n 5]]>\n </prop>\n</data>','# \'check_ping\' command definition'),
	(20,'check_tcp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p $ARG1$]]>\n  </prop>\n</data>','# \'check_tcp\' command definition'),
	(21,'check_dns','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_dns -t 30 -s $HOSTADDRESS$ -H \"$ARG1$\"]]>\n  </prop>\n</data>','# \'check_dns\' command definition'),
	(22,'check_local_disk','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_disk -m -w \"$ARG1$\" -c \"$ARG2$\" -p \"$ARG3$\"]]>\n  </prop>\n</data>','# \'check_local_disk\' command definition'),
	(23,'process-host-perfdata','check','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"$LASTHOSTCHECK$\\t$HOSTNAME$\\t$HOSTSTATE$\\t$HOSTATTEMPT$\\t$HOSTSTATETYPE$\\t$HOSTEXECUTIONTIME$\\t$HOSTOUTPUT$\\t$HOSTPERFDATA$\\n\" >> /usr/local/nagios/var/host-perfdata.dat]]>\n </prop>\n</data>','# \'process-host-perfdata\' command definition'),
	(24,'check_alive','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_icmp -H $HOSTADDRESS$ -w 3000.0,80% -c 5000.0,100% -n 1]]>\n  </prop>\n</data>',NULL),
	(25,'check_tcp_ssh','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 22]]>\n  </prop>\n</data>',NULL),
	(26,'check_by_ssh_disk','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_disk -w $ARG1$ -c $ARG2$ -p $ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(27,'check_by_ssh_load','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_load -w $ARG1$ -c $ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(28,'check_by_ssh_mem','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_mem.pl -U -w $ARG1$ -c $ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(29,'check_by_ssh_process_count','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -w $ARG1$ -c $ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(30,'check_by_ssh_swap','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_swap -w $ARG1$ -c $ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(31,'check_snmp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -o \"$ARG1$\" -r \"$ARG2$\" -l \"$ARG3$\" -C \'$USER7$\']]>\n  </prop>\n</data>',NULL),
	(32,'check_snmp_if','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -C \'$USER7$\' -o \"IF-MIB::ifInOctets.$ARG1$,IF-MIB::ifOutOctets.$ARG1$ ,IF-MIB::ifInDiscards.$ARG1$,IF-MIB::ifOutDiscards.$ARG1$,IF-MIB::ifInErrors.$ARG1$,IF-MIB::ifOutErrors.$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(33,'check_snmp_bandwidth','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -C \'$USER7$\' -o \"IF-MIB::ifInOctets.$ARG1$,IF-MIB::ifOutOctets.$ARG1$,IF-MIB::ifSpeed.$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(34,'check_ifoperstatus','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_ifoperstatus -k \"$ARG1$\" -H $HOSTADDRESS$ -C \"$USER7$\"]]>\n  </prop>\n</data>',NULL),
	(35,'host-notify-by-sendemail','notify','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"<html>\\n<table width=\'auto\' style=\'background-color: #E6DBC3\"\\;\" min-width: 350px\'>\\n<caption style=\'font-weight: bold\"\\;\" background-color: #B39962\'><b>GroundWork Host<br>$NOTIFICATIONTYPE$ Notification</b></caption>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Host:</td>\\n<td><b><a href=\'http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$\'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Host State:</td>\\n<td style=\'background-color: #F3EDE1\'><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Host Info:</td>\\n<td><b>$HOSTOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Host Notes:</td>\\n<td><b>`echo \'$HOSTNOTES$\' | sed \'s/<br>/\\\\n/g\'`</b></td>\\n</tr>\\n</table>\\n</html>\\n\" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u \"[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$ is $HOSTSTATE$\"]]>\n </prop>\n</data>',NULL),
	(36,'service-notify-by-sendemail','notify','<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"command_line\"><![CDATA[/usr/bin/printf \"%b\" \"<html>\\n<table width=\'auto\' style=\'background-color: #E6DBC3\"\\;\" min-width: 350px\'>\\n<caption style=\'font-weight: bold\"\\;\" background-color: #B39962\'>GroundWork Service<br>$NOTIFICATIONTYPE$ Notification</caption>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Host:</td>\\n<td><b><a href=\'http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$\'>$HOSTNAME$</a> ($HOSTADDRESS$)</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Host State:</td>\\n<td><b>$HOSTSTATE$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Service:</td>\\n<td><b><a href=\'http://$USER32$/portal-statusviewer/urlmap?host=$HOSTNAME$&service=$SERVICEDESC$\'>$SERVICEDESC$</a></b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Service State:</td>\\n<td style=\'background-color: #F3EDE1\'><b>$SERVICESTATE$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Service Info:</td>\\n<td><b>$SERVICEOUTPUT$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Time:</td>\\n<td><b>$LONGDATETIME$</b></td>\\n</tr>\\n<tr>\\n<td style=\'background-color: #CCB98F\'>Service Notes:</td>\\n<td><b>`echo \'$SERVICENOTES$\' | sed \'s/<br>/\\\\n/g\'`</b></td>\\n</tr>\\n</table>\\n</html>\\n\" | /usr/bin/sendEmail -s $USER13$ -q -f $ADMINEMAIL$ -t $CONTACTEMAIL$ -u \"[GW] $NOTIFICATIONTYPE$ alert: $HOSTNAME$/$SERVICEDESC$ is $SERVICESTATE$\"]]>\n </prop>\n</data>',NULL),
	(37,'check_mysql','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_mysql -H $HOSTADDRESS$ -d \"$ARG1$\" -u \"$ARG2$\" -p \"$USER6$\"]]>\n  </prop>\n</data>',NULL),
	(38,'check_mysql_engine','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_mysql -H $HOSTADDRESS$ -u \"$ARG1$\" -p \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(39,'check_mysql_engine_nopw','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_mysql -H $HOSTADDRESS$ -u \"$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(40,'check_local_procs_string','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_procs -w \"$ARG1$\" -c \"$ARG2$\" -a \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(41,'check_local_mem','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_mem.pl -U -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(42,'check_tcp_nsca','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$ -p 5667]]>\n  </prop>\n</data>',NULL),
	(43,'check_nagios','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nagios -F /usr/local/nagios/var/status.log -e 5 -C bin/.nagios.bin]]>\n  </prop>\n</data>',NULL),
	(44,'check_nagios_latency','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nagios_latency.pl]]>\n  </prop>\n</data>',NULL),
	(45,'check_local_procs_arg','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_procs -w \"$ARG1$\" -c \"$ARG2$\" -a \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(46,'check_local_swap','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_swap -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(47,'check_tcp_dns','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 53]]>\n  </prop>\n</data>',NULL),
	(48,'check_udp_dns','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_udp -H $HOSTADDRESS$ -p 53 -s \"4500 003d 668f 4000 4011 4ce9 c0a8 02f0\"]]>\n  </prop>\n</data>',NULL),
	(49,'check_dns_expect','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_dns -t 30 -s $HOSTADDRESS$ -H \"$ARG1$\" -a \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(50,'check_tcp_ftp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 21]]>\n  </prop>\n</data>',NULL),
	(51,'check_tcp_https','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 443]]>\n  </prop>\n</data>',NULL),
	(52,'check_https','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_http -t 60 -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -S]]>\n  </prop>\n</data>',NULL),
	(53,'check_tcp_port','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p \"$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(54,'check_http_port','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_http -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -p \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(55,'check_tcp_imaps','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 993]]>\n  </prop>\n</data>',NULL),
	(56,'check_imaps','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_imap -t 60 -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -p 993 -S]]>\n  </prop>\n</data>',NULL),
	(57,'check_tcp_nntps','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 563]]>\n  </prop>\n</data>',NULL),
	(58,'check_nntps','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nntp -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -p 563 -S]]>\n  </prop>\n</data>',NULL),
	(59,'check_tcp_nrpe','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 5666]]>\n  </prop>\n</data>',NULL),
	(60,'check_nrpe','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$]]>\n  </prop>\n</data>',NULL),
	(61,'check_tcp_pop3s','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 995]]>\n  </prop>\n</data>',NULL),
	(62,'check_pop3s','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_pop -t 60 -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -S]]>\n  </prop>\n</data>',NULL),
	(63,'check_tcp_smtp','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -p 25]]>\n  </prop>\n</data>',NULL),
	(64,'check_nrpe_print_queue','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_printqueue -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(65,'check_nrpe_cpu','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_cpu -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(66,'check_nrpe_disk','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_disk -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(67,'check_nrpe_disk_transfers','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_disktransfers -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(68,'check_nrpe_exchange_mailbox_receiveq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_mbox_recvq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(69,'check_nrpe_exchange_mailbox_sendq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_mbox_sendq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(70,'check_nrpe_exchange_mta_workq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_mta_workq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(71,'check_nrpe_exchange_public_receiveq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_pub_recvq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(72,'check_nrpe_exchange_public_sendq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_exchange_pub_sendq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(73,'check_nrpe_iis_bytes_received','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_bytes_received -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(74,'check_nrpe_iis_bytes_sent','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_bytes_sent -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(75,'check_nrpe_iis_bytes_total','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_bytes_total -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(76,'check_nrpe_iis_current_connections','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_currentconnections -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(77,'check_nrpe_iis_current_nonanonymous_users','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_curnonanonusers -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(78,'check_nrpe_iis_get_requests','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_get_requests -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(79,'check_nrpe_iis_maximum_connections','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_maximumconnections -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(80,'check_nrpe_iis_post_requests','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_post_requests -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(81,'check_nrpe_iis_private_bytes','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_privatebytes -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(82,'check_nrpe_iis_total_not_found_errors','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_iis_totalnotfounderrors -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(83,'check_nrpe_local_cpu','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_cpu -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(84,'check_nrpe_local_disk','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_disk -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(85,'check_nrpe_local_memory','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mem -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(86,'check_nrpe_local_pagefile','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c check_pagefile_counter -a \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(87,'check_nrpe_mem','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mem -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(88,'check_nrpe_mssql_buffer_cache_hits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_buf_cache_hit -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(89,'check_nrpe_mssql_deadlocks','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_deadlocks -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(90,'check_nrpe_mssql_full_scans','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_fullscans -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(92,'check_nrpe_mssql_lock_wait_time','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_lock_wait_time -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(93,'check_nrpe_mssql_lock_waits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_lock_waits -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(94,'check_nrpe_mssql_log_growths','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_log_growth -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(95,'check_nrpe_mssql_log_used','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_log_used -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(96,'check_nrpe_mssql_memory_grants_pending','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_memgrantspending -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(97,'check_nrpe_memory_pages','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_swapping -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(98,'check_nrpe_mssql_transactions','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_transactions -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(99,'check_nrpe_mssql_users','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $HOSTADDRESS$ -c get_mssql_users -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(148,'check_apache','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_apache.pl -H $HOSTADDRESS$]]>\n  </prop>\n</data>',NULL),
	(149,'check_nt_cpuload','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v CPULOAD -l \"$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(150,'check_nt_useddiskspace','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v USEDDISKSPACE -l $ARG1$ -w $ARG2$ -c $ARG3$]]>\n  </prop>\n</data>',NULL),
	(151,'check_nt_counter_exchange_mailrq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\MSExchangeIS Mailbox(_Total)\\\\Receive Queue Size\",\"Receive Queue Size is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(152,'check_nt_counter_exchange_mailsq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\MSExchangeIS Mailbox(_Total)\\\\Send Queue Size\",\"Send Queue Size is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(153,'check_nt_counter_exchange_mtawq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\MSExchangeMTA\\\\Work Queue Length\",\"Work Queue Length is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(154,'check_nt_counter_exchange_publicrq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\MSExchangeIS Public(_Total)\\\\Receive Queue Size\",\"Receive Queue Size is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(155,'check_nt_counter_exchange_publicsq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\MSExchangeIS Public(_Total)\\\\Send Queue Size\",\"Send Queue Size is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(156,'check_nt_memuse','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v MEMUSE -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(157,'check_udp_nsclient','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_udp -H $HOSTADDRESS$ -p $USER19$]]>\n  </prop>\n</data>',NULL),
	(158,'check_ldap','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_ldap -t 60  -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -b \"$ARG3$\" -3]]>\n  </prop>\n</data>',NULL),
	(159,'check_tcp_ldap','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -t 60 -H $HOSTADDRESS$ -w 2 -c 4 -p 389]]>\n  </prop>\n</data>',NULL),
	(160,'check_snmptraps','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_snmptraps.pl $HOSTNAME$ $ARG1$ $ARG2$ $ARG3$]]>\n  </prop>\n</data>',NULL),
	(161,'check_ssh','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_ssh -H $HOSTADDRESS$ -t 60]]>\n  </prop>\n</data>',NULL),
	(162,'check_by_ssh_apache','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_apache.pl -H $HOSTADDRESS$\"]]>\n  </prop>\n</data>',NULL),
	(164,'check_by_ssh_process_proftpd','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -c 1:1 -a proftpd:\\ \\(accepting\"]]>\n  </prop>\n</data>',NULL),
	(165,'check_by_ssh_process_slapd','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -w $ARG1$ -c $ARG2$ -C slapd\"]]>\n  </prop>\n</data>',NULL),
	(166,'check_by_ssh_mysql','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_mysql -H $HOSTADDRESS$ -d $ARG1$ -u $ARG2$ -p $ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(167,'check_by_ssh_mysql_engine','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_mysql -H $HOSTADDRESS$ -u $ARG1$ -p $ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(168,'check_by_ssh_process_args','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -w $ARG1$ -c $ARG2$ -a $ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(169,'check_sendmail','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_smtp -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -C \"ehlo groundworkopensource.com\" -R \"ENHANCEDSTATUSCODES\" -f nagios@$HOSTADDRESS$]]>\n  </prop>\n</data>',NULL),
	(170,'check_by_ssh_mailq_sendmail','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"sudo $USER22$/check_mailq -w $ARG1$ -c $ARG2$ -M sendmail\"]]>\n  </prop>\n</data>',NULL),
	(171,'check_by_ssh_process_crond','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -c 1:1 -a crond\"]]>\n  </prop>\n</data>',NULL),
	(172,'check_by_ssh_process_sendmail_accept','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -c 1:1 -a sendmail:\\ accepting\\ con\"]]>\n  </prop>\n</data>',NULL),
	(173,'check_by_ssh_process_sendmail_qrunner','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -c 1:1 -a sendmail:\\ Queue\\ runner\"]]>\n  </prop>\n</data>',NULL),
	(174,'check_by_ssh_process_xinetd','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -c 1:1 -a xinetd\"]]>\n  </prop>\n</data>',NULL),
	(175,'check_by_ssh_process_cmd','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -w $ARG1$ -c $ARG2$ -C $ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(176,'check_wmi_cpu','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H \"$USER21$\" -c get_cpu -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(177,'check_wmi_disk','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_disk -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(178,'check_wmi_mem','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mem -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(179,'check_wmi_exchange_mailbox_receiveq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_mbox_recvq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(180,'check_wmi_exchange_mailbox_sendq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_mbox_sendq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(181,'check_wmi_service','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -H $USER21$ -t 60 -c get_service -a \"$HOSTADDRESS$\" \"$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(182,'check_wmi_exchange_mta_workq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_mta_workq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(183,'check_wmi_exchange_public_receiveq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_pub_recvq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(184,'check_wmi_exchange_public_sendq','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_exchange_pub_sendq -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(185,'check_wmi_iis_bytes_received','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_bytes_received -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(186,'check_wmi_iis_bytes_sent','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_bytes_sent -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(187,'check_wmi_iis_bytes_total','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_bytes_total -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(188,'check_wmi_iis_current_connections','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_currentconnections -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(189,'check_wmi_iis_current_nonanonymous_users','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_curnonanonusers -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(190,'check_wmi_iis_get_requests','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_get_requests -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(191,'check_wmi_iis_maximum_connections','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_maximumconnections -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(192,'check_wmi_iis_post_requests','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_post_requests -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(193,'check_wmi_iis_private_bytes','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_privatebytes -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(194,'check_wmi_iis_total_not_found_errors','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_iis_totalnotfounderrors -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(225,'check_citrix','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_ica_master_browser.pl -I $HOSTADDRESS$ -P $HOSTADDRESS$]]>\n  </prop>\n</data>',NULL),
	(226,'check_wmi_mssql_buffer_cache_hits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_buf_cache_hit -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(227,'check_wmi_mssql_deadlocks','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_deadlocks -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(228,'check_wmi_disk_transfers','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_disktransfers -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(229,'check_wmi_mssql_full_scans','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_fullscans -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(231,'check_wmi_mssql_lock_wait_time','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_lock_wait_time -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(232,'check_wmi_mssql_lock_waits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_lock_waits -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(233,'check_wmi_mssql_log_growths','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_log_growth -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(234,'check_wmi_mssql_log_used','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_log_used -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(235,'check_wmi_mssql_memory_grants_pending','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_memgrantspending -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(236,'check_wmi_memory_pages','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_swapping -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(237,'check_wmi_mssql_transactions','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_transactions -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\" \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(238,'check_wmi_mssql_users','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -t 60 -H $USER21$ -c get_mssql_users -a \"$HOSTADDRESS$\" \"$ARG1$\" \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(246,'check_nt_counter_disktransfers','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\PhysicalDisk(_Total)\\\\Disk Transfers/sec\",\"PhysicalDisk(_Total) Disk Transfers/sec is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(247,'check_nt_counter_memory_pages','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\Memory\\\\Pages/sec\",\"Pages per Sec is %.f\" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(248,'check_nt_counter_mssql_bufcache_hits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Buffer Manager\\\\Buffer cache hit ratio\",\"SQLServer:Buffer Manager Buffer cache hit ratio is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(249,'check_nt_counter_mssql_deadlocks','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Locks(_Total)\\\\Number of Deadlocks/sec\",\"SQLServer:Locks(_Total) Number of Deadlocks/sec is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(250,'check_nt_counter_mssql_latch_waits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Latches\\\\Latch Waits/sec\",\"SQLServer:Latches Latch Waits/sec is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(251,'check_nt_counter_mssql_lock_wait_time','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Locks(_Total)\\\\Lock Wait Time (ms)\",\"SQLServer:Locks(_Total) Lock Wait Time (ms) is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(252,'check_nt_counter_mssql_lock_waits','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Locks(_Total)\\\\Lock Waits/sec\",\"SQLServer:Locks(_Total) Lock Waits/sec is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(253,'check_nt_counter_mssql_log_growths','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Databases(_Total)\\\\Log Growths\",\"SQLServer:Databases(_Total) Log Growths is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(254,'check_nt_counter_mssql_log_used','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Databases(_Total)\\\\Percent Log Used\",\"SQLServer:Databases(_Total) Percent Log Used is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(255,'check_nt_counter_mssql_memory_grants_pending','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Memory Manager\\\\Memory Grants Pending\",\"SQLServer:Memory Manager Memory Grants Pending is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(256,'check_nt_counter_mssql_transactions','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\SQLServer:Databases(_Total)\\\\Transactions/sec\",\"SQLServer:Databases(_Total) Transactions/sec is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(257,'check_nt_counter_network_interface','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -H $HOSTADDRESS$ -p $USER19$ -s $USER4$ -v COUNTER -l \"\\\\Network Interface(MS TCP Loopback interface)\\\\Bytes Total/sec\",\"Network Interface(MS TCP Loopback interface) Bytes Total/sec is %.f \" -w \"$ARG1$\" -c \"$ARG2$\"]]>\n  </prop>\n</data>',NULL),
	(258,'check_by_ssh_process_named','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procs -c 1:1 -C named -a /etc/named.conf\"]]>\n  </prop>\n</data>',NULL),
	(259,'check_syslog','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_syslog_gw.pl -l $ARG1$ -s /tmp/$HOSTNAME$.tmp -x $ARG2$ -a $HOSTADDRESS$]]>\n  </prop>\n</data>',NULL),
	(260,'check_imap','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_imap -t 60 -H $HOSTADDRESS$ -w \"$ARG1$\" -c \"$ARG2$\" -p 143]]>\n  </prop>\n</data>',NULL),
	(262,'process_service_perfdata_db','other','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER2$/process_service_perf_db.pl \"$LASTSERVICECHECK$\" \"$HOSTNAME$\" \"$SERVICEDESC$\" \"$SERVICEOUTPUT$\" \"$SERVICEPERFDATA$\"]]>\n  </prop>\n</data>',NULL),
	(263,'check_snmp_alive','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_snmp -H $HOSTADDRESS$ -o .1.3.6.1.2.1.1.3.0 -l \"Uptime is \" -C \'$USER7$\']]>\n  </prop>\n</data>',NULL),
	(264,'check_nt','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nt -p $USER19$ -s $USER4$ -H $HOSTADDRESS$ -v CLIENTVERSION]]>\n  </prop>\n</data>',NULL),
	(265,'check_nrpe_service','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_nrpe -H $HOSTADDRESS$ -t 60 -c get_service -a \"$HOSTADDRESS$\" \"$ARG1$\"]]>\n  </prop>\n</data>',NULL),
	(267,'check_local_proc_cpu','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_procl.sh --cpu -w \"$ARG1$\" -c \"$ARG2$\" -p \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(268,'check_local_proc_mem','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_procl.sh --mem -w \"$ARG1$\" -c \"$ARG2$\" -p \"$ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(269,'check_dir_size','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_dir_size.sh $ARG1$ $ARG2$ $ARG3$]]>\n  </prop>\n</data>',NULL),
	(270,'check_tcp_gw_listener','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_tcp -H $HOSTADDRESS$ -w $ARG1$ -c $ARG2$ -p 4913]]>\n  </prop>\n</data>',NULL),
	(271,'launch_perfdata_process','other','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER2$/launch_perf_data_processing]]>\n  </prop>\n</data>',NULL),
	(272,'check_by_ssh_cpu_proc','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procl.sh --cpu -w $ARG1$ -c $ARG2$ -p $ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(273,'check_by_ssh_mem_proc','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER22$/check_procl.sh --mem -w $ARG1$ -c $ARG2$ -p $ARG3$\"]]>\n  </prop>\n</data>',NULL),
	(274,'check_by_ssh_nagios_latency','check','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_by_ssh -H $HOSTADDRESS$ -t 60 -l \"$USER17$\" -C \"$USER1$/check_nagios_latency.pl\"]]>\n  </prop>\n</data>',NULL),
	(275,'check_msg','check','<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n  <prop name=\"command_line\"><![CDATA[$USER1$/check_dummy $ARG1$ $ARG2$]]>\n  </prop>\n</data>',NULL);
/*!40000 ALTER TABLE `commands` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_command`
--

DROP TABLE IF EXISTS `contact_command`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_command` (
  `contacttemplate_id` smallint(4) unsigned NOT NULL default '0',
  `type` varchar(50) NOT NULL default '',
  `command_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contacttemplate_id`,`type`,`command_id`),
  KEY `command_id` (`command_id`),
  CONSTRAINT `contact_command_ibfk_1` FOREIGN KEY (`command_id`) REFERENCES `commands` (`command_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_command_ibfk_2` FOREIGN KEY (`contacttemplate_id`) REFERENCES `contact_templates` (`contacttemplate_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_command`
--

LOCK TABLES `contact_command` WRITE;
/*!40000 ALTER TABLE `contact_command` DISABLE KEYS */;
INSERT INTO `contact_command` VALUES
	(1,'host',5),
	(2,'host',5),
	(2,'service',9),
	(1,'service',14),
	(2,'service',14),
	(2,'host',17);
/*!40000 ALTER TABLE `contact_command` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_command_overrides`
--

DROP TABLE IF EXISTS `contact_command_overrides`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_command_overrides` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `type` varchar(50) NOT NULL default '',
  `command_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`type`,`command_id`),
  KEY `command_id` (`command_id`),
  CONSTRAINT `contact_command_overrides_ibfk_1` FOREIGN KEY (`command_id`) REFERENCES `commands` (`command_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_command_overrides_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_command_overrides`
--

LOCK TABLES `contact_command_overrides` WRITE;
/*!40000 ALTER TABLE `contact_command_overrides` DISABLE KEYS */;
/*!40000 ALTER TABLE `contact_command_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_group`
--

DROP TABLE IF EXISTS `contact_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_group` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `group_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`group_id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `contact_group_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_group_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_group`
--

LOCK TABLES `contact_group` WRITE;
/*!40000 ALTER TABLE `contact_group` DISABLE KEYS */;
/*!40000 ALTER TABLE `contact_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_host`
--

DROP TABLE IF EXISTS `contact_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_host` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `contact_host_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_host_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_host`
--

LOCK TABLES `contact_host` WRITE;
/*!40000 ALTER TABLE `contact_host` DISABLE KEYS */;
INSERT INTO `contact_host` VALUES
	(1,1);
/*!40000 ALTER TABLE `contact_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_host_profile`
--

DROP TABLE IF EXISTS `contact_host_profile`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_host_profile` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`hostprofile_id`),
  KEY `hostprofile_id` (`hostprofile_id`),
  CONSTRAINT `contact_host_profile_ibfk_1` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_host_profile_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_host_profile`
--

LOCK TABLES `contact_host_profile` WRITE;
/*!40000 ALTER TABLE `contact_host_profile` DISABLE KEYS */;
/*!40000 ALTER TABLE `contact_host_profile` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_host_template`
--

DROP TABLE IF EXISTS `contact_host_template`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_host_template` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `hosttemplate_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`hosttemplate_id`),
  KEY `hosttemplate_id` (`hosttemplate_id`),
  CONSTRAINT `contact_host_template_ibfk_1` FOREIGN KEY (`hosttemplate_id`) REFERENCES `host_templates` (`hosttemplate_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_host_template_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_host_template`
--

LOCK TABLES `contact_host_template` WRITE;
/*!40000 ALTER TABLE `contact_host_template` DISABLE KEYS */;
INSERT INTO `contact_host_template` VALUES
	(1,1);
/*!40000 ALTER TABLE `contact_host_template` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_hostgroup`
--

DROP TABLE IF EXISTS `contact_hostgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_hostgroup` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`hostgroup_id`),
  KEY `hostgroup_id` (`hostgroup_id`),
  CONSTRAINT `contact_hostgroup_ibfk_1` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_hostgroup_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_hostgroup`
--

LOCK TABLES `contact_hostgroup` WRITE;
/*!40000 ALTER TABLE `contact_hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `contact_hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_overrides`
--

DROP TABLE IF EXISTS `contact_overrides`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_overrides` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `host_notification_period` smallint(4) unsigned default NULL,
  `service_notification_period` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`contact_id`),
  CONSTRAINT `contact_overrides_ibfk_1` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_overrides`
--

LOCK TABLES `contact_overrides` WRITE;
/*!40000 ALTER TABLE `contact_overrides` DISABLE KEYS */;
INSERT INTO `contact_overrides` VALUES
	(1,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"host_notification_options\"><![CDATA[d,r]]>\n  </prop>\n  <prop name=\"service_notification_options\"><![CDATA[c,r]]>\n  </prop>\n</data>'),
	(2,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"host_notification_options\"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name=\"service_notification_options\"><![CDATA[u,c,w,r]]>\n  </prop>\n</data>');
/*!40000 ALTER TABLE `contact_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_service`
--

DROP TABLE IF EXISTS `contact_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_service` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `service_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`service_id`),
  KEY `service_id` (`service_id`),
  CONSTRAINT `contact_service_ibfk_1` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_service_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_service`
--

LOCK TABLES `contact_service` WRITE;
/*!40000 ALTER TABLE `contact_service` DISABLE KEYS */;
INSERT INTO `contact_service` VALUES
	(1,1),
	(1,2),
	(1,3),
	(1,4);
/*!40000 ALTER TABLE `contact_service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_service_name`
--

DROP TABLE IF EXISTS `contact_service_name`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_service_name` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`servicename_id`),
  KEY `servicename_id` (`servicename_id`),
  CONSTRAINT `contact_service_name_ibfk_1` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_service_name_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_service_name`
--

LOCK TABLES `contact_service_name` WRITE;
/*!40000 ALTER TABLE `contact_service_name` DISABLE KEYS */;
/*!40000 ALTER TABLE `contact_service_name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_service_template`
--

DROP TABLE IF EXISTS `contact_service_template`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_service_template` (
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  `servicetemplate_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contact_id`,`servicetemplate_id`),
  KEY `servicetemplate_id` (`servicetemplate_id`),
  CONSTRAINT `contact_service_template_ibfk_1` FOREIGN KEY (`servicetemplate_id`) REFERENCES `service_templates` (`servicetemplate_id`) ON DELETE CASCADE,
  CONSTRAINT `contact_service_template_ibfk_2` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_service_template`
--

LOCK TABLES `contact_service_template` WRITE;
/*!40000 ALTER TABLE `contact_service_template` DISABLE KEYS */;
INSERT INTO `contact_service_template` VALUES
	(1,1);
/*!40000 ALTER TABLE `contact_service_template` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contact_templates`
--

DROP TABLE IF EXISTS `contact_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contact_templates` (
  `contacttemplate_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `host_notification_period` smallint(4) unsigned default NULL,
  `service_notification_period` smallint(4) unsigned default NULL,
  `data` text,
  `comment` text,
  PRIMARY KEY  (`contacttemplate_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contact_templates`
--

LOCK TABLES `contact_templates` WRITE;
/*!40000 ALTER TABLE `contact_templates` DISABLE KEYS */;
INSERT INTO `contact_templates` VALUES
	(1,'generic-contact-1',1,1,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"host_notification_options\"><![CDATA[d,r]]>\n  </prop>\n  <prop name=\"service_notification_options\"><![CDATA[c,r]]>\n  </prop>\n </data>',NULL),
	(2,'generic-contact-2',3,3,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"host_notification_options\"><![CDATA[d,u,r]]>\n </prop>\n <prop name=\"service_notification_options\"><![CDATA[u,c,w,r]]>\n </prop>\n</data>',NULL);
/*!40000 ALTER TABLE `contact_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_contact`
--

DROP TABLE IF EXISTS `contactgroup_contact`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_contact` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `contact_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`contact_id`),
  KEY `contact_id` (`contact_id`),
  CONSTRAINT `contactgroup_contact_ibfk_1` FOREIGN KEY (`contact_id`) REFERENCES `contacts` (`contact_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_contact_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_contact`
--

LOCK TABLES `contactgroup_contact` WRITE;
/*!40000 ALTER TABLE `contactgroup_contact` DISABLE KEYS */;
INSERT INTO `contactgroup_contact` VALUES
	(1,1),
	(1,2);
/*!40000 ALTER TABLE `contactgroup_contact` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_group`
--

DROP TABLE IF EXISTS `contactgroup_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_group` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `group_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`group_id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `contactgroup_group_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_group_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_group`
--

LOCK TABLES `contactgroup_group` WRITE;
/*!40000 ALTER TABLE `contactgroup_group` DISABLE KEYS */;
/*!40000 ALTER TABLE `contactgroup_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_host`
--

DROP TABLE IF EXISTS `contactgroup_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_host` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `contactgroup_host_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_host_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_host`
--

LOCK TABLES `contactgroup_host` WRITE;
/*!40000 ALTER TABLE `contactgroup_host` DISABLE KEYS */;
INSERT INTO `contactgroup_host` VALUES
	(1,1);
/*!40000 ALTER TABLE `contactgroup_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_host_profile`
--

DROP TABLE IF EXISTS `contactgroup_host_profile`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_host_profile` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`hostprofile_id`),
  KEY `hostprofile_id` (`hostprofile_id`),
  CONSTRAINT `contactgroup_host_profile_ibfk_1` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_host_profile_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_host_profile`
--

LOCK TABLES `contactgroup_host_profile` WRITE;
/*!40000 ALTER TABLE `contactgroup_host_profile` DISABLE KEYS */;
/*!40000 ALTER TABLE `contactgroup_host_profile` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_host_template`
--

DROP TABLE IF EXISTS `contactgroup_host_template`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_host_template` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `hosttemplate_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`hosttemplate_id`),
  KEY `hosttemplate_id` (`hosttemplate_id`),
  CONSTRAINT `contactgroup_host_template_ibfk_1` FOREIGN KEY (`hosttemplate_id`) REFERENCES `host_templates` (`hosttemplate_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_host_template_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_host_template`
--

LOCK TABLES `contactgroup_host_template` WRITE;
/*!40000 ALTER TABLE `contactgroup_host_template` DISABLE KEYS */;
INSERT INTO `contactgroup_host_template` VALUES
	(1,1);
/*!40000 ALTER TABLE `contactgroup_host_template` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_hostgroup`
--

DROP TABLE IF EXISTS `contactgroup_hostgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_hostgroup` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`hostgroup_id`),
  KEY `hostgroup_id` (`hostgroup_id`),
  CONSTRAINT `contactgroup_hostgroup_ibfk_1` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_hostgroup_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_hostgroup`
--

LOCK TABLES `contactgroup_hostgroup` WRITE;
/*!40000 ALTER TABLE `contactgroup_hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `contactgroup_hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_service`
--

DROP TABLE IF EXISTS `contactgroup_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_service` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `service_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`service_id`),
  KEY `service_id` (`service_id`),
  CONSTRAINT `contactgroup_service_ibfk_1` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_service_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_service`
--

LOCK TABLES `contactgroup_service` WRITE;
/*!40000 ALTER TABLE `contactgroup_service` DISABLE KEYS */;
INSERT INTO `contactgroup_service` VALUES
	(1,1),
	(1,2),
	(1,3),
	(1,4);
/*!40000 ALTER TABLE `contactgroup_service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_service_name`
--

DROP TABLE IF EXISTS `contactgroup_service_name`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_service_name` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`servicename_id`),
  KEY `servicename_id` (`servicename_id`),
  CONSTRAINT `contactgroup_service_name_ibfk_1` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_service_name_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_service_name`
--

LOCK TABLES `contactgroup_service_name` WRITE;
/*!40000 ALTER TABLE `contactgroup_service_name` DISABLE KEYS */;
/*!40000 ALTER TABLE `contactgroup_service_name` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroup_service_template`
--

DROP TABLE IF EXISTS `contactgroup_service_template`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroup_service_template` (
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  `servicetemplate_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`contactgroup_id`,`servicetemplate_id`),
  KEY `servicetemplate_id` (`servicetemplate_id`),
  CONSTRAINT `contactgroup_service_template_ibfk_1` FOREIGN KEY (`servicetemplate_id`) REFERENCES `service_templates` (`servicetemplate_id`) ON DELETE CASCADE,
  CONSTRAINT `contactgroup_service_template_ibfk_2` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroup_service_template`
--

LOCK TABLES `contactgroup_service_template` WRITE;
/*!40000 ALTER TABLE `contactgroup_service_template` DISABLE KEYS */;
INSERT INTO `contactgroup_service_template` VALUES
	(1,1);
/*!40000 ALTER TABLE `contactgroup_service_template` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contactgroups`
--

DROP TABLE IF EXISTS `contactgroups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contactgroups` (
  `contactgroup_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `alias` varchar(255) NOT NULL default '',
  `comment` text,
  PRIMARY KEY  (`contactgroup_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contactgroups`
--

LOCK TABLES `contactgroups` WRITE;
/*!40000 ALTER TABLE `contactgroups` DISABLE KEYS */;
INSERT INTO `contactgroups` VALUES
	(1,'nagiosadmin','Linux Administrators','# \'linux-admins\' contact group definition');
/*!40000 ALTER TABLE `contactgroups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `contacts`
--

DROP TABLE IF EXISTS `contacts`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `contacts` (
  `contact_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `alias` varchar(255) NOT NULL default '',
  `email` text,
  `pager` text,
  `contacttemplate_id` smallint(4) unsigned default NULL,
  `status` tinyint(1) default NULL,
  `comment` text,
  PRIMARY KEY  (`contact_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `contacts`
--

LOCK TABLES `contacts` WRITE;
/*!40000 ALTER TABLE `contacts` DISABLE KEYS */;
INSERT INTO `contacts` VALUES
	(1,'jdoe','John Doe','jdoe@localhost',NULL,1,1,'# \'jdoe\' contact definition'),
	(2,'nagiosadmin','Nagios Admin','nagios-admin@localhost','pagenagios-admin@localhost',2,1,'# \'nagios\' contact definition');
/*!40000 ALTER TABLE `contacts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `datatype`
--

DROP TABLE IF EXISTS `datatype`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `datatype` (
  `datatype_id` int(8) unsigned NOT NULL auto_increment,
  `type` varchar(100) NOT NULL default '',
  `location` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`datatype_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `datatype`
--

LOCK TABLES `datatype` WRITE;
UNLOCK TABLES;

--
-- Table structure for table `discover_filter`
--

DROP TABLE IF EXISTS `discover_filter`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `discover_filter` (
  `filter_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `type` varchar(50) default NULL,
  `filter` text,
  PRIMARY KEY  (`filter_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `discover_filter`
--

LOCK TABLES `discover_filter` WRITE;
/*!40000 ALTER TABLE `discover_filter` DISABLE KEYS */;
/*!40000 ALTER TABLE `discover_filter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `discover_group`
--

DROP TABLE IF EXISTS `discover_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `discover_group` (
  `group_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` text,
  `config` text,
  `schema_id` smallint(4) unsigned default NULL,
  PRIMARY KEY  (`group_id`),
  KEY `schema_id` (`schema_id`),
  CONSTRAINT `discover_group_ibfk_1` FOREIGN KEY (`schema_id`) REFERENCES `import_schema` (`schema_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `discover_group`
--

LOCK TABLES `discover_group` WRITE;
/*!40000 ALTER TABLE `discover_group` DISABLE KEYS */;
/*!40000 ALTER TABLE `discover_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `discover_group_filter`
--

DROP TABLE IF EXISTS `discover_group_filter`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `discover_group_filter` (
  `group_id` smallint(4) unsigned NOT NULL default '0',
  `filter_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`group_id`,`filter_id`),
  KEY `filter_id` (`filter_id`),
  CONSTRAINT `discover_group_filter_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `discover_group` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `discover_group_filter_ibfk_2` FOREIGN KEY (`filter_id`) REFERENCES `discover_filter` (`filter_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `discover_group_filter`
--

LOCK TABLES `discover_group_filter` WRITE;
/*!40000 ALTER TABLE `discover_group_filter` DISABLE KEYS */;
/*!40000 ALTER TABLE `discover_group_filter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `discover_group_method`
--

DROP TABLE IF EXISTS `discover_group_method`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `discover_group_method` (
  `group_id` smallint(4) unsigned NOT NULL default '0',
  `method_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`group_id`,`method_id`),
  KEY `method_id` (`method_id`),
  CONSTRAINT `discover_group_method_ibfk_1` FOREIGN KEY (`method_id`) REFERENCES `discover_method` (`method_id`) ON DELETE CASCADE,
  CONSTRAINT `discover_group_method_ibfk_2` FOREIGN KEY (`group_id`) REFERENCES `discover_group` (`group_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `discover_group_method`
--

LOCK TABLES `discover_group_method` WRITE;
/*!40000 ALTER TABLE `discover_group_method` DISABLE KEYS */;
/*!40000 ALTER TABLE `discover_group_method` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `discover_method`
--

DROP TABLE IF EXISTS `discover_method`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `discover_method` (
  `method_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` text,
  `config` text,
  `type` varchar(50) default NULL,
  PRIMARY KEY  (`method_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `discover_method`
--

LOCK TABLES `discover_method` WRITE;
/*!40000 ALTER TABLE `discover_method` DISABLE KEYS */;
/*!40000 ALTER TABLE `discover_method` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `discover_method_filter`
--

DROP TABLE IF EXISTS `discover_method_filter`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `discover_method_filter` (
  `method_id` smallint(4) unsigned NOT NULL default '0',
  `filter_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`method_id`,`filter_id`),
  KEY `filter_id` (`filter_id`),
  CONSTRAINT `discover_method_filter_ibfk_1` FOREIGN KEY (`method_id`) REFERENCES `discover_method` (`method_id`) ON DELETE CASCADE,
  CONSTRAINT `discover_method_filter_ibfk_2` FOREIGN KEY (`filter_id`) REFERENCES `discover_filter` (`filter_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `discover_method_filter`
--

LOCK TABLES `discover_method_filter` WRITE;
/*!40000 ALTER TABLE `discover_method_filter` DISABLE KEYS */;
/*!40000 ALTER TABLE `discover_method_filter` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `escalation_templates`
--

DROP TABLE IF EXISTS `escalation_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `escalation_templates` (
  `template_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `type` varchar(50) NOT NULL default '',
  `data` text,
  `comment` text,
  `escalation_period` smallint(4) unsigned default NULL,
  PRIMARY KEY  (`template_id`,`name`,`type`),
  UNIQUE KEY `name` (`name`),
  KEY `escalation_period` (`escalation_period`),
  CONSTRAINT `escalation_templates_ibfk_1` FOREIGN KEY (`escalation_period`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `escalation_templates`
--

LOCK TABLES `escalation_templates` WRITE;
/*!40000 ALTER TABLE `escalation_templates` DISABLE KEYS */;
/*!40000 ALTER TABLE `escalation_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `escalation_tree_template`
--

DROP TABLE IF EXISTS `escalation_tree_template`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `escalation_tree_template` (
  `tree_id` smallint(4) unsigned NOT NULL default '0',
  `template_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`tree_id`,`template_id`),
  KEY `template_id` (`template_id`),
  CONSTRAINT `escalation_tree_template_ibfk_1` FOREIGN KEY (`template_id`) REFERENCES `escalation_templates` (`template_id`) ON DELETE CASCADE,
  CONSTRAINT `escalation_tree_template_ibfk_2` FOREIGN KEY (`tree_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `escalation_tree_template`
--

LOCK TABLES `escalation_tree_template` WRITE;
/*!40000 ALTER TABLE `escalation_tree_template` DISABLE KEYS */;
/*!40000 ALTER TABLE `escalation_tree_template` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `escalation_trees`
--

DROP TABLE IF EXISTS `escalation_trees`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `escalation_trees` (
  `tree_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `description` varchar(100) default NULL,
  `type` varchar(50) NOT NULL default '',
  PRIMARY KEY  (`tree_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `escalation_trees`
--

LOCK TABLES `escalation_trees` WRITE;
/*!40000 ALTER TABLE `escalation_trees` DISABLE KEYS */;
/*!40000 ALTER TABLE `escalation_trees` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `extended_host_info_templates`
--

DROP TABLE IF EXISTS `extended_host_info_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `extended_host_info_templates` (
  `hostextinfo_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `data` text,
  `script` varchar(255) default NULL,
  `comment` text,
  PRIMARY KEY  (`hostextinfo_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `extended_host_info_templates`
--

LOCK TABLES `extended_host_info_templates` WRITE;
/*!40000 ALTER TABLE `extended_host_info_templates` DISABLE KEYS */;
/*!40000 ALTER TABLE `extended_host_info_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `extended_info_coords`
--

DROP TABLE IF EXISTS `extended_info_coords`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `extended_info_coords` (
  `host_id` int(4) unsigned NOT NULL default '0',
  `data` text,
  PRIMARY KEY  (`host_id`),
  CONSTRAINT `extended_info_coords_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `extended_info_coords`
--

LOCK TABLES `extended_info_coords` WRITE;
/*!40000 ALTER TABLE `extended_info_coords` DISABLE KEYS */;
/*!40000 ALTER TABLE `extended_info_coords` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `extended_service_info_templates`
--

DROP TABLE IF EXISTS `extended_service_info_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `extended_service_info_templates` (
  `serviceextinfo_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `data` text,
  `script` varchar(255) default NULL,
  `comment` text,
  PRIMARY KEY  (`serviceextinfo_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `extended_service_info_templates`
--

LOCK TABLES `extended_service_info_templates` WRITE;
/*!40000 ALTER TABLE `extended_service_info_templates` DISABLE KEYS */;
INSERT INTO `extended_service_info_templates` VALUES
	(1,'number_graph','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"notes_url\"><![CDATA[/graphs/cgi-bin/label_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name=\"icon_image\"><![CDATA[services.gif]]>\n  </prop>\n  <prop name=\"icon_image_alt\"><![CDATA[Service Detail]]>\n  </prop>\n</data>',NULL,NULL),
	(2,'unix_load_graph','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"notes_url\"><![CDATA[/graphs/cgi-bin/label_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name=\"icon_image\"><![CDATA[services.gif]]>\n  </prop>\n  <prop name=\"icon_image_alt\"><![CDATA[Service Detail]]>\n  </prop>\n</data>',NULL,NULL),
	(3,'percent_graph','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"notes_url\"><![CDATA[/graphs/cgi-bin/label_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name=\"icon_image\"><![CDATA[services.gif]]>\n  </prop>\n  <prop name=\"icon_image_alt\"><![CDATA[Service Detail]]>\n  </prop>\n</data>',NULL,NULL),
	(4,'snmp_if','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"notes_url\"><![CDATA[/graphs/cgi-bin/percent_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name=\"icon_image\"><![CDATA[services.gif]]>\n  </prop>\n  <prop name=\"icon_image_alt\"><![CDATA[Service Detail]]>\n  </prop>\n</data>',NULL,NULL),
	(5,'snmp_ifbandwidth','<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"notes_url\"><![CDATA[/graphs/cgi-bin/percent_graph.cgi?host=$HOSTNAME$&service=$SERVICENAME$]]>\n  </prop>\n  <prop name=\"icon_image\"><![CDATA[services.gif]]>\n  </prop>\n  <prop name=\"icon_image_alt\"><![CDATA[Service Detail]]>\n  </prop>\n</data>',NULL,NULL);
/*!40000 ALTER TABLE `extended_service_info_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `external_host`
--

DROP TABLE IF EXISTS `external_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `external_host` (
  `external_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  `data` text,
  `modified` tinyint(1) default NULL,
  PRIMARY KEY  (`external_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `external_host_ibfk_1` FOREIGN KEY (`external_id`) REFERENCES `externals` (`external_id`) ON DELETE CASCADE,
  CONSTRAINT `external_host_ibfk_2` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `external_host`
--

LOCK TABLES `external_host` WRITE;
/*!40000 ALTER TABLE `external_host` DISABLE KEYS */;
/*!40000 ALTER TABLE `external_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `external_host_profile`
--

DROP TABLE IF EXISTS `external_host_profile`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `external_host_profile` (
  `external_id` smallint(4) unsigned NOT NULL default '0',
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`external_id`,`hostprofile_id`),
  KEY `hostprofile_id` (`hostprofile_id`),
  CONSTRAINT `external_host_profile_ibfk_1` FOREIGN KEY (`external_id`) REFERENCES `externals` (`external_id`) ON DELETE CASCADE,
  CONSTRAINT `external_host_profile_ibfk_2` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `external_host_profile`
--

LOCK TABLES `external_host_profile` WRITE;
/*!40000 ALTER TABLE `external_host_profile` DISABLE KEYS */;
/*!40000 ALTER TABLE `external_host_profile` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `external_service`
--

DROP TABLE IF EXISTS `external_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `external_service` (
  `external_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  `service_id` int(8) unsigned NOT NULL default '0',
  `data` text,
  `modified` tinyint(1) default NULL,
  PRIMARY KEY  (`external_id`,`host_id`,`service_id`),
  KEY `host_id` (`host_id`),
  KEY `service_id` (`service_id`),
  CONSTRAINT `external_service_ibfk_1` FOREIGN KEY (`external_id`) REFERENCES `externals` (`external_id`) ON DELETE CASCADE,
  CONSTRAINT `external_service_ibfk_2` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `external_service_ibfk_3` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `external_service`
--

LOCK TABLES `external_service` WRITE;
/*!40000 ALTER TABLE `external_service` DISABLE KEYS */;
/*!40000 ALTER TABLE `external_service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `external_service_names`
--

DROP TABLE IF EXISTS `external_service_names`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `external_service_names` (
  `external_id` smallint(4) unsigned NOT NULL default '0',
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`external_id`,`servicename_id`),
  KEY `servicename_id` (`servicename_id`),
  CONSTRAINT `external_service_names_ibfk_1` FOREIGN KEY (`external_id`) REFERENCES `externals` (`external_id`) ON DELETE CASCADE,
  CONSTRAINT `external_service_names_ibfk_2` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `external_service_names`
--

LOCK TABLES `external_service_names` WRITE;
/*!40000 ALTER TABLE `external_service_names` DISABLE KEYS */;
/*!40000 ALTER TABLE `external_service_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `externals`
--

DROP TABLE IF EXISTS `externals`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `externals` (
  `external_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` varchar(50) default NULL,
  `type` varchar(20) NOT NULL default '',
  `display` text,
  `handler` text,
  PRIMARY KEY  (`external_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `externals`
--

LOCK TABLES `externals` WRITE;
/*!40000 ALTER TABLE `externals` DISABLE KEYS */;
/*!40000 ALTER TABLE `externals` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `host_dependencies`
--

DROP TABLE IF EXISTS `host_dependencies`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `host_dependencies` (
  `host_id` int(6) unsigned NOT NULL default '0',
  `parent_id` int(6) unsigned NOT NULL default '0',
  `data` text,
  `comment` text,
  PRIMARY KEY  (`host_id`,`parent_id`),
  KEY `parent_id` (`parent_id`),
  CONSTRAINT `host_dependencies_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `host_dependencies_ibfk_2` FOREIGN KEY (`parent_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `host_dependencies`
--

LOCK TABLES `host_dependencies` WRITE;
/*!40000 ALTER TABLE `host_dependencies` DISABLE KEYS */;
/*!40000 ALTER TABLE `host_dependencies` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `host_overrides`
--

DROP TABLE IF EXISTS `host_overrides`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `host_overrides` (
  `host_id` int(6) unsigned NOT NULL default '0',
  `check_period` smallint(4) unsigned default NULL,
  `notification_period` smallint(4) unsigned default NULL,
  `check_command` smallint(4) unsigned default NULL,
  `event_handler` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`host_id`),
  CONSTRAINT `host_overrides_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `host_overrides`
--

LOCK TABLES `host_overrides` WRITE;
/*!40000 ALTER TABLE `host_overrides` DISABLE KEYS */;
INSERT INTO `host_overrides` VALUES
	(1,NULL,3,7,NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"max_check_attempts\"><![CDATA[10]]>\n </prop>\n <prop name=\"notification_options\"><![CDATA[d,u,r]]>\n </prop>\n <prop name=\"notification_interval\"><![CDATA[480]]>\n </prop>\n <prop name=\"notification_period\"><![CDATA[3]]>\n </prop>\n</data>');
/*!40000 ALTER TABLE `host_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `host_parent`
--

DROP TABLE IF EXISTS `host_parent`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `host_parent` (
  `host_id` int(6) unsigned NOT NULL default '0',
  `parent_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`host_id`,`parent_id`),
  KEY `parent_id` (`parent_id`),
  CONSTRAINT `host_parent_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `host_parent_ibfk_2` FOREIGN KEY (`parent_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `host_parent`
--

LOCK TABLES `host_parent` WRITE;
/*!40000 ALTER TABLE `host_parent` DISABLE KEYS */;
/*!40000 ALTER TABLE `host_parent` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `host_service`
--

DROP TABLE IF EXISTS `host_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `host_service` (
  `host_service_id` int(8) unsigned NOT NULL auto_increment,
  `host` varchar(255) NOT NULL default '',
  `service` varchar(255) NOT NULL default '',
  `label` varchar(100) NOT NULL default '',
  `dataname` varchar(100) NOT NULL default '',
  `datatype_id` int(8) unsigned default '0',
  PRIMARY KEY  (`host_service_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `host_service`
--

LOCK TABLES `host_service` WRITE;
UNLOCK TABLES;

--
-- Table structure for table `host_templates`
--

DROP TABLE IF EXISTS `host_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `host_templates` (
  `hosttemplate_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `check_period` smallint(4) unsigned default NULL,
  `notification_period` smallint(4) unsigned default NULL,
  `check_command` smallint(4) unsigned default NULL,
  `event_handler` smallint(4) unsigned default NULL,
  `data` text,
  `comment` text,
  PRIMARY KEY  (`hosttemplate_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `host_templates`
--

LOCK TABLES `host_templates` WRITE;
/*!40000 ALTER TABLE `host_templates` DISABLE KEYS */;
INSERT INTO `host_templates` VALUES
	(1,'generic-host',3,3,7,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"flap_detection_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"check_freshness\"><![CDATA[-zero-]]>\n  </prop>\n  <prop name=\"notifications_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"event_handler_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"process_perf_data\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"active_checks_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"passive_checks_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"retain_status_information\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"max_check_attempts\"><![CDATA[3]]>\n  </prop>\n  <prop name=\"notification_options\"><![CDATA[d,u,r]]>\n  </prop>\n  <prop name=\"retain_nonstatus_information\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"obsess_over_host\"><![CDATA[-zero-]]>\n  </prop>\n  <prop name=\"check_interval\"><![CDATA[-zero-]]>\n  </prop>\n  <prop name=\"notification_interval\"><![CDATA[60]]>\n  </prop>\n </data>','# Generic host definition template');
/*!40000 ALTER TABLE `host_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostgroup_host`
--

DROP TABLE IF EXISTS `hostgroup_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `hostgroup_host` (
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`hostgroup_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `hostgroup_host_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `hostgroup_host_ibfk_2` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `hostgroup_host`
--

LOCK TABLES `hostgroup_host` WRITE;
/*!40000 ALTER TABLE `hostgroup_host` DISABLE KEYS */;
INSERT INTO `hostgroup_host` VALUES
	(1,1);
/*!40000 ALTER TABLE `hostgroup_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostgroups`
--

DROP TABLE IF EXISTS `hostgroups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `hostgroups` (
  `hostgroup_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `alias` varchar(255) NOT NULL default '',
  `hostprofile_id` smallint(4) unsigned default NULL,
  `host_escalation_id` smallint(4) unsigned default NULL,
  `service_escalation_id` smallint(4) unsigned default NULL,
  `status` tinyint(1) default NULL,
  `comment` text,
  `notes` varchar(4096) default NULL,
  PRIMARY KEY  (`hostgroup_id`),
  UNIQUE KEY `name` (`name`),
  KEY `hostprofile_id` (`hostprofile_id`),
  KEY `host_escalation_id` (`host_escalation_id`),
  KEY `service_escalation_id` (`service_escalation_id`),
  CONSTRAINT `hostgroups_ibfk_1` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE SET NULL,
  CONSTRAINT `hostgroups_ibfk_2` FOREIGN KEY (`host_escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL,
  CONSTRAINT `hostgroups_ibfk_3` FOREIGN KEY (`service_escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `hostgroups`
--

LOCK TABLES `hostgroups` WRITE;
/*!40000 ALTER TABLE `hostgroups` DISABLE KEYS */;
INSERT INTO `hostgroups` VALUES
	(1,'Linux Servers','Linux Servers',NULL,NULL,NULL,1,'# \'linux-boxes\' host group definition',NULL);
/*!40000 ALTER TABLE `hostgroups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hostprofile_overrides`
--

DROP TABLE IF EXISTS `hostprofile_overrides`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `hostprofile_overrides` (
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  `check_period` smallint(4) unsigned default NULL,
  `notification_period` smallint(4) unsigned default NULL,
  `check_command` smallint(4) unsigned default NULL,
  `event_handler` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`hostprofile_id`),
  CONSTRAINT `hostprofile_overrides_ibfk_1` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `hostprofile_overrides`
--

LOCK TABLES `hostprofile_overrides` WRITE;
/*!40000 ALTER TABLE `hostprofile_overrides` DISABLE KEYS */;
INSERT INTO `hostprofile_overrides` VALUES
	(1,NULL,NULL,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n </data>');
/*!40000 ALTER TABLE `hostprofile_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `hosts`
--

DROP TABLE IF EXISTS `hosts`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `hosts` (
  `host_id` int(6) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `alias` varchar(255) NOT NULL default '',
  `address` varchar(50) NOT NULL default '',
  `os` varchar(50) default NULL,
  `hosttemplate_id` smallint(4) unsigned default NULL,
  `hostextinfo_id` smallint(4) unsigned default NULL,
  `hostprofile_id` smallint(4) unsigned default NULL,
  `host_escalation_id` smallint(4) unsigned default NULL,
  `service_escalation_id` smallint(4) unsigned default NULL,
  `status` tinyint(1) default NULL,
  `comment` text,
  `notes` varchar(4096) default NULL,
  PRIMARY KEY  (`host_id`),
  UNIQUE KEY `name` (`name`),
  KEY `hostextinfo_id` (`hostextinfo_id`),
  KEY `hostprofile_id` (`hostprofile_id`),
  KEY `host_escalation_id` (`host_escalation_id`),
  KEY `service_escalation_id` (`service_escalation_id`),
  CONSTRAINT `hosts_ibfk_1` FOREIGN KEY (`hostextinfo_id`) REFERENCES `extended_host_info_templates` (`hostextinfo_id`) ON DELETE SET NULL,
  CONSTRAINT `hosts_ibfk_2` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE SET NULL,
  CONSTRAINT `hosts_ibfk_3` FOREIGN KEY (`host_escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL,
  CONSTRAINT `hosts_ibfk_4` FOREIGN KEY (`service_escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `hosts`
--

LOCK TABLES `hosts` WRITE;
/*!40000 ALTER TABLE `hosts` DISABLE KEYS */;
INSERT INTO `hosts` VALUES
	(1,'localhost','Linux Server #1','127.0.0.1','n/a',1,NULL,NULL,NULL,NULL,1,'# \'linux1\' host definition',NULL);
/*!40000 ALTER TABLE `hosts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_column`
--

DROP TABLE IF EXISTS `import_column`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_column` (
  `column_id` smallint(4) unsigned NOT NULL auto_increment,
  `schema_id` smallint(4) unsigned default NULL,
  `name` varchar(255) default NULL,
  `position` smallint(4) unsigned default NULL,
  `delimiter` varchar(50) default NULL,
  PRIMARY KEY  (`column_id`),
  KEY `schema_id` (`schema_id`),
  CONSTRAINT `import_column_ibfk_1` FOREIGN KEY (`schema_id`) REFERENCES `import_schema` (`schema_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_column`
--

LOCK TABLES `import_column` WRITE;
/*!40000 ALTER TABLE `import_column` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_column` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_hosts`
--

DROP TABLE IF EXISTS `import_hosts`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_hosts` (
  `import_hosts_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `alias` varchar(255) default NULL,
  `address` varchar(50) default NULL,
  `hostprofile_id` smallint(4) unsigned default NULL,
  PRIMARY KEY  (`import_hosts_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_hosts`
--

LOCK TABLES `import_hosts` WRITE;
/*!40000 ALTER TABLE `import_hosts` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_hosts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match`
--

DROP TABLE IF EXISTS `import_match`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match` (
  `match_id` smallint(4) unsigned NOT NULL auto_increment,
  `column_id` smallint(4) unsigned default NULL,
  `name` varchar(255) default NULL,
  `match_order` smallint(4) unsigned default NULL,
  `match_type` varchar(255) default NULL,
  `match_string` varchar(255) default NULL,
  `rule` varchar(255) default NULL,
  `object` varchar(255) default NULL,
  `hostprofile_id` smallint(4) unsigned default NULL,
  `servicename_id` smallint(4) unsigned default NULL,
  `arguments` varchar(255) default NULL,
  PRIMARY KEY  (`match_id`),
  KEY `hostprofile_id` (`hostprofile_id`),
  KEY `column_id` (`column_id`),
  KEY `servicename_id` (`servicename_id`),
  CONSTRAINT `import_match_ibfk_1` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_ibfk_2` FOREIGN KEY (`column_id`) REFERENCES `import_column` (`column_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_ibfk_3` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match`
--

LOCK TABLES `import_match` WRITE;
/*!40000 ALTER TABLE `import_match` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match_contactgroup`
--

DROP TABLE IF EXISTS `import_match_contactgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match_contactgroup` (
  `match_id` smallint(4) unsigned NOT NULL default '0',
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`match_id`,`contactgroup_id`),
  KEY `contactgroup_id` (`contactgroup_id`),
  CONSTRAINT `import_match_contactgroup_ibfk_1` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_contactgroup_ibfk_2` FOREIGN KEY (`match_id`) REFERENCES `import_match` (`match_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match_contactgroup`
--

LOCK TABLES `import_match_contactgroup` WRITE;
/*!40000 ALTER TABLE `import_match_contactgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match_contactgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match_group`
--

DROP TABLE IF EXISTS `import_match_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match_group` (
  `match_id` smallint(4) unsigned NOT NULL default '0',
  `group_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`match_id`,`group_id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `import_match_group_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_group_ibfk_2` FOREIGN KEY (`match_id`) REFERENCES `import_match` (`match_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match_group`
--

LOCK TABLES `import_match_group` WRITE;
/*!40000 ALTER TABLE `import_match_group` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match_hostgroup`
--

DROP TABLE IF EXISTS `import_match_hostgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match_hostgroup` (
  `match_id` smallint(4) unsigned NOT NULL default '0',
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`match_id`,`hostgroup_id`),
  KEY `hostgroup_id` (`hostgroup_id`),
  CONSTRAINT `import_match_hostgroup_ibfk_1` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_hostgroup_ibfk_2` FOREIGN KEY (`match_id`) REFERENCES `import_match` (`match_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match_hostgroup`
--

LOCK TABLES `import_match_hostgroup` WRITE;
/*!40000 ALTER TABLE `import_match_hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match_hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match_parent`
--

DROP TABLE IF EXISTS `import_match_parent`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match_parent` (
  `match_id` smallint(4) unsigned NOT NULL default '0',
  `parent_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`match_id`,`parent_id`),
  KEY `parent_id` (`parent_id`),
  CONSTRAINT `import_match_parent_ibfk_1` FOREIGN KEY (`parent_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_parent_ibfk_2` FOREIGN KEY (`match_id`) REFERENCES `import_match` (`match_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match_parent`
--

LOCK TABLES `import_match_parent` WRITE;
/*!40000 ALTER TABLE `import_match_parent` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match_parent` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match_servicename`
--

DROP TABLE IF EXISTS `import_match_servicename`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match_servicename` (
  `match_id` smallint(4) unsigned NOT NULL default '0',
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`match_id`,`servicename_id`),
  KEY `servicename_id` (`servicename_id`),
  CONSTRAINT `import_match_servicename_ibfk_1` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_servicename_ibfk_2` FOREIGN KEY (`match_id`) REFERENCES `import_match` (`match_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match_servicename`
--

LOCK TABLES `import_match_servicename` WRITE;
/*!40000 ALTER TABLE `import_match_servicename` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match_servicename` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_match_serviceprofile`
--

DROP TABLE IF EXISTS `import_match_serviceprofile`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_match_serviceprofile` (
  `match_id` smallint(4) unsigned NOT NULL default '0',
  `serviceprofile_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`match_id`,`serviceprofile_id`),
  KEY `serviceprofile_id` (`serviceprofile_id`),
  CONSTRAINT `import_match_serviceprofile_ibfk_1` FOREIGN KEY (`serviceprofile_id`) REFERENCES `profiles_service` (`serviceprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `import_match_serviceprofile_ibfk_2` FOREIGN KEY (`match_id`) REFERENCES `import_match` (`match_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_match_serviceprofile`
--

LOCK TABLES `import_match_serviceprofile` WRITE;
/*!40000 ALTER TABLE `import_match_serviceprofile` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_match_serviceprofile` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_schema`
--

DROP TABLE IF EXISTS `import_schema`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_schema` (
  `schema_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `delimiter` varchar(50) default NULL,
  `description` text,
  `type` varchar(255) default NULL,
  `sync_object` varchar(50) default NULL,
  `smart_name` tinyint(1) default '0',
  `hostprofile_id` smallint(4) unsigned default '0',
  `data_source` varchar(255) default NULL,
  PRIMARY KEY  (`schema_id`),
  KEY `hostprofile_id` (`hostprofile_id`),
  CONSTRAINT `import_schema_ibfk_1` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_schema`
--

LOCK TABLES `import_schema` WRITE;
/*!40000 ALTER TABLE `import_schema` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_schema` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `import_services`
--

DROP TABLE IF EXISTS `import_services`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `import_services` (
  `import_services_id` smallint(4) unsigned NOT NULL auto_increment,
  `import_hosts_id` smallint(4) unsigned default NULL,
  `description` varchar(255) default NULL,
  `check_command_id` smallint(4) unsigned default NULL,
  `command_line` varchar(255) default NULL,
  `command_line_trans` varchar(255) default NULL,
  `servicename_id` smallint(4) unsigned default NULL,
  `serviceprofile_id` smallint(4) unsigned default NULL,
  PRIMARY KEY  (`import_services_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `import_services`
--

LOCK TABLES `import_services` WRITE;
/*!40000 ALTER TABLE `import_services` DISABLE KEYS */;
/*!40000 ALTER TABLE `import_services` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_group_child`
--

DROP TABLE IF EXISTS `monarch_group_child`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_group_child` (
  `group_id` smallint(4) unsigned NOT NULL default '0',
  `child_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`group_id`,`child_id`),
  KEY `child_id` (`child_id`),
  CONSTRAINT `monarch_group_child_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `monarch_group_child_ibfk_2` FOREIGN KEY (`child_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_group_child`
--

LOCK TABLES `monarch_group_child` WRITE;
/*!40000 ALTER TABLE `monarch_group_child` DISABLE KEYS */;
/*!40000 ALTER TABLE `monarch_group_child` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_group_host`
--

DROP TABLE IF EXISTS `monarch_group_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_group_host` (
  `group_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`group_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `monarch_group_host_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `monarch_group_host_ibfk_2` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_group_host`
--

LOCK TABLES `monarch_group_host` WRITE;
/*!40000 ALTER TABLE `monarch_group_host` DISABLE KEYS */;
/*!40000 ALTER TABLE `monarch_group_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_group_hostgroup`
--

DROP TABLE IF EXISTS `monarch_group_hostgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_group_hostgroup` (
  `group_id` smallint(4) unsigned NOT NULL default '0',
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`group_id`,`hostgroup_id`),
  KEY `hostgroup_id` (`hostgroup_id`),
  CONSTRAINT `monarch_group_hostgroup_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `monarch_group_hostgroup_ibfk_2` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_group_hostgroup`
--

LOCK TABLES `monarch_group_hostgroup` WRITE;
/*!40000 ALTER TABLE `monarch_group_hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `monarch_group_hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_group_macro`
--

DROP TABLE IF EXISTS `monarch_group_macro`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_group_macro` (
  `group_id` smallint(4) unsigned NOT NULL default '0',
  `macro_id` smallint(4) unsigned NOT NULL default '0',
  `value` varchar(255) default NULL,
  PRIMARY KEY  (`group_id`,`macro_id`),
  KEY `macro_id` (`macro_id`),
  CONSTRAINT `monarch_group_macro_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE,
  CONSTRAINT `monarch_group_macro_ibfk_2` FOREIGN KEY (`macro_id`) REFERENCES `monarch_macros` (`macro_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_group_macro`
--

LOCK TABLES `monarch_group_macro` WRITE;
/*!40000 ALTER TABLE `monarch_group_macro` DISABLE KEYS */;
/*!40000 ALTER TABLE `monarch_group_macro` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_group_props`
--

DROP TABLE IF EXISTS `monarch_group_props`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_group_props` (
  `prop_id` smallint(4) unsigned NOT NULL auto_increment,
  `group_id` smallint(4) unsigned default NULL,
  `name` varchar(255) default NULL,
  `type` varchar(20) default NULL,
  `value` varchar(255) default NULL,
  PRIMARY KEY  (`prop_id`),
  KEY `group_id` (`group_id`),
  CONSTRAINT `monarch_group_props_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `monarch_groups` (`group_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_group_props`
--

LOCK TABLES `monarch_group_props` WRITE;
/*!40000 ALTER TABLE `monarch_group_props` DISABLE KEYS */;
/*!40000 ALTER TABLE `monarch_group_props` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_groups`
--

DROP TABLE IF EXISTS `monarch_groups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_groups` (
  `group_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` varchar(255) default NULL,
  `location` text,
  `status` tinyint(1) default '0',
  `data` text,
  PRIMARY KEY  (`group_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_groups`
--

LOCK TABLES `monarch_groups` WRITE;
/*!40000 ALTER TABLE `monarch_groups` DISABLE KEYS */;
INSERT INTO `monarch_groups` VALUES
	(1,'windows-gdma-2.1','Group for configuration of Windows GDMA systems','/usr/local/groundwork/apache2/htdocs/gdma',NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"label_enabled\"><![CDATA[]]>\n </prop>\n <prop name=\"label\"><![CDATA[]]>\n </prop>\n <prop name=\"nagios_etc\"><![CDATA[]]>\n </prop>\n <prop name=\"use_hosts\"><![CDATA[]]>\n </prop>\n <prop name=\"inherit_host_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_host_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"host_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"host_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n</data>'),
	(2,'unix-gdma-2.1','Group for configuration of Linux and Solaris GDMA systems','/usr/local/groundwork/apache2/htdocs/gdma',NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"label_enabled\"><![CDATA[]]>\n </prop>\n <prop name=\"label\"><![CDATA[]]>\n </prop>\n <prop name=\"nagios_etc\"><![CDATA[]]>\n </prop>\n <prop name=\"use_hosts\"><![CDATA[]]>\n </prop>\n <prop name=\"inherit_host_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_host_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_active_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"inherit_service_passive_checks_enabled\"><![CDATA[1]]>\n </prop>\n <prop name=\"host_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"host_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_active_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n <prop name=\"service_passive_checks_enabled\"><![CDATA[-zero-]]>\n </prop>\n</data>');
/*!40000 ALTER TABLE `monarch_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `monarch_macros`
--

DROP TABLE IF EXISTS `monarch_macros`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `monarch_macros` (
  `macro_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `value` varchar(255) default NULL,
  `description` varchar(255) default NULL,
  PRIMARY KEY  (`macro_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `monarch_macros`
--

LOCK TABLES `monarch_macros` WRITE;
/*!40000 ALTER TABLE `monarch_macros` DISABLE KEYS */;
/*!40000 ALTER TABLE `monarch_macros` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `performanceconfig`
--

DROP TABLE IF EXISTS `performanceconfig`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `performanceconfig` (
  `performanceconfig_id` int(8) unsigned NOT NULL auto_increment,
  `host` varchar(255) NOT NULL default '',
  `service` varchar(255) NOT NULL default '',
  `type` varchar(100) NOT NULL default '',
  `enable` tinyint(1) default '0',
  `parseregx_first` tinyint(1) default '0',
  `service_regx` tinyint(1) default '0',
  `label` varchar(100) NOT NULL default '',
  `rrdname` varchar(100) NOT NULL default '',
  `rrdcreatestring` text NOT NULL,
  `rrdupdatestring` text NOT NULL,
  `graphcgi` text,
  `perfidstring` varchar(100) NOT NULL default '',
  `parseregx` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`performanceconfig_id`),
  UNIQUE KEY `host` (`host`,`service`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `performanceconfig`
--

LOCK TABLES `performanceconfig` WRITE;
/*!40000 ALTER TABLE `performanceconfig` DISABLE KEYS */;
INSERT INTO `performanceconfig` VALUES
	(4,'*','snmp_if_','nagios',1,1,1,'Interface Statistics','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:in:COUNTER:1800:U:U DS:out:COUNTER:1800:U:U DS:indis:COUNTER:1800:U:U DS:outdis:COUNTER:1800:U:U DS:inerr:COUNTER:1800:U:U  DS:outerr:COUNTER:1800:U:U RRA:AVERAGE:0.5:1:2880 RRA:AVERAGE:0.5:5:4032','$RRDTOOL$ update $RRDNAME$ -t in:out:indis:outdis:inerr:outerr $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$:$VALUE4$:$VALUE5$:$VALUE6$  2>&1','',' ','SNMP OK - (\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)\\s(\\d+)'),
	(5,'*','snmp_ifbandwidth_','nagios',1,NULL,1,'Interface Bandwidth Utilization','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:in:COUNTER:1800:U:U DS:out:COUNTER:1800:U:U DS:ifspeed:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ -t in:out:ifspeed $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$ 2>&1','',' ','SNMP OK - (\\d+)\\s+(\\d+)\\s+(\\d+)'),
	(13,'*','icmp_ping','nagios',1,0,1,'ICMP Ping Response Time','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:rta:GAUGE:1800:U:U DS:pl:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$ 2>&1','\'rrdtool graph - --imgformat=PNG --title=\"ICMP Performance\" --rigid --base=1000 --height=120 --width=700 --alt-autoscale-max --lower-limit=0 --vertical-label=\"Time and Percent\" --slope-mode DEF:a=\"rrd_source\":ds_source_1:AVERAGE DEF:b=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=b CDEF:cdefb=a,100,/ AREA:cdefa#43C6DB:\"Response Time (ms) \" GPRINT:cdefa:LAST:\"Current\\:%8.2lf %s\" GPRINT:cdefa:AVERAGE:\"Average\\:%8.2lf %s\" GPRINT:cdefa:MAX:\"Maximum\\:%8.2lf %s\\n\" LINE1:cdefb#307D7E:\"Percent Loss       \" GPRINT:cdefb:LAST:\"Current\\:%8.2lf %s\" GPRINT:cdefb:AVERAGE:\"Average\\:%8.2lf %s\" GPRINT:cdefb:MAX:\"Maximum\\:%8.2lf %s\"\'','',''),
	(14,'*','local_disk','nagios',1,0,1,'Disk Utilization','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE \r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE\r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE\r\n DEF:m=\"rrd_source\":ds_source_3:AVERAGE\r\n CDEF:cdefa=a,m,/,100,* \r\n CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w\r\n CDEF:cdefc=c\r\n CDEF:cdefm=m  \r\n AREA:a#C35617:\"Space Used\\: \"\r\n LINE:cdefa#FFCC00:\r\n GPRINT:a:LAST:\"%.2lf MB\\l\"\r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\"\r\n GPRINT:cdefw:AVERAGE:\"%.2lf\" \r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\" \r\n GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" \r\n GPRINT:cdefa:AVERAGE:\"Percentage Space Used\"=%.2lf\r\n GPRINT:cdefm:AVERAGE:\"Maximum Capacity\"=%.2lf\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF\r\n AREA:cdefws#FFFF00\r\n CDEF:cdefcs=a,cdefc,GT,a,0,IF\r\n AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y  -l 0\'','',' '),
	(15,'*','local_load','nagios',1,0,0,'Load Averages','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$  RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$VALUE2$:$WARN2$:$CRIT2$:$VALUE3$:$WARN3$:$CRIT3$ 2>&1','\'rrdtool graph - --imgformat=PNG --slope-mode \r\n DEF:a=rrd_source:ds_source_0:AVERAGE \r\n DEF:aw=\"rrd_source\":ds_source_1:AVERAGE\r\n DEF:ac=\"rrd_source\":ds_source_2:AVERAGE\r\n DEF:b=rrd_source:ds_source_3:AVERAGE \r\n DEF:bw=\"rrd_source\":ds_source_4:AVERAGE\r\n DEF:bc=\"rrd_source\":ds_source_5:AVERAGE\r\n DEF:c=rrd_source:ds_source_6:AVERAGE\r\n DEF:cw=\"rrd_source\":ds_source_7:AVERAGE\r\n DEF:cc=\"rrd_source\":ds_source_8:AVERAGE\r\n CDEF:cdefa=a \r\n CDEF:cdefb=b \r\n CDEF:cdefc=c \r\n AREA:cdefa#FF6600:\"One Minute Load Average\" GPRINT:cdefa:MIN:min=%.2lf  GPRINT:cdefa:AVERAGE:avg=%.2lf  \r\n GPRINT:cdefa:MAX:\"max=%.2lf\\l\"\r\n LINE:aw#FFCC33:\"1 min avg Warning Threshold\" \r\n GPRINT:aw:LAST:\"%.1lf\"\r\n LINE:ac#FF0000:\"1 min avg Critical Threshold\"\r\n GPRINT:ac:LAST:\"%.1lf\\l\"\r\n LINE2:cdefb#3300FF:\"Five Minute Load Average\"\r\n GPRINT:cdefb:MIN:min=%.2lf\r\n GPRINT:cdefb:AVERAGE:avg=%.2lf\r\n GPRINT:cdefb:MAX:\"max=%.2lf\\l\" \r\n LINE:bw#6666CC:\"5 min avg Warning Threshold\"\r\n GPRINT:bw:LAST:\"%.1lf\"\r\n LINE:bc#CC0000:\"5 min avg Critical Threshold\"\r\n GPRINT:bc:LAST:\"%.1lf\\l\"\r\n LINE3:cdefc#999999:\"Fifteen Minute Load Average\"   \r\n GPRINT:cdefc:MIN:min=%.2lf\r\n GPRINT:cdefc:AVERAGE:avg=%.2lf \r\n GPRINT:cdefc:MAX:\"max=%.2lf\\l\" \r\n LINE:cw#CCCC99:\"15 min avg Warning Threshold\"\r\n GPRINT:cw:LAST:\"%.1lf\"\r\n LINE:cc#990000:\"15 min avg Critical Threshold\"\r\n GPRINT:cc:LAST:\"%.1lf\\l\"\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120\'','',' '),
	(16,'*','local_mem','nagios',1,0,1,'Memory Utilization','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$ DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE \r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE \r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE \r\n CDEF:cdefa=a\r\n CDEF:cdefb=a,0.99,* \r\n CDEF:cdefw=w \r\n CDEF:cdefc=c \r\n CDEF:cdefm=c,1.05,*\r\n AREA:a#33FFFF \r\n AREA:cdefb#3399FF:\"Memory Utilized\\:\" \r\n GPRINT:a:LAST:\"%.2lf Percent\"\r\n GPRINT:cdefa:MIN:min=%.2lf\r\n GPRINT:cdefa:AVERAGE:avg=%.2lf\r\n GPRINT:cdefa:MAX:max=\"%.2lf\\l\" \r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" \r\n GPRINT:cdefw:LAST:\"%.2lf\" \r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\" \r\n GPRINT:cdefc:LAST:\"%.2lf\\l\"  \r\n COMMENT:\"Service\\: SERVICE\"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -u 100 -l 0 --rigid\'','','([\\d\\.]+)%'),
	(17,'*','local_mysql_engine','nagios',1,1,1,'MySQL Queries Per Second','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1','/graphs/cgi-bin/number_graph.cgi',' ','Queries per second avg: ([\\d\\.]+)'),
	(18,'*','local_process','nagios',1,1,1,'Process Count','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:number:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1','\'rrdtool graph - DEF:a=\"rrd_source\":ds_source_0:AVERAGE CDEF:cdefa=a AREA:cdefa#0000FF:\"Number of Processes\" GPRINT:cdefa:MIN:min=%.2lf GPRINT:cdefa:AVERAGE:avg=%.2lf GPRINT:cdefa:MAX:max=%.2lf  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 -l 0\'','','(\\d+) process'),
	(19,'*','local_nagios_latency','nagios',1,0,0,'Nagios Service Check Latency in Seconds','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:min:GAUGE:1800:U:U DS:max:GAUGE:1800:U:U DS:avg:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE \r\n DEF:b=\"rrd_source\":ds_source_1:AVERAGE \r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE \r\n CDEF:cdefa=a\r\n CDEF:cdefb=b  \r\n CDEF:cdefc=c \r\n AREA:cdefb#66FFFF:\"Maximum Latency\\: \"\r\n GPRINT:cdefb:LAST:\"%.2lf sec\"\r\n GPRINT:cdefb:MIN:min=%.2lf \r\n GPRINT:cdefb:AVERAGE:avg=%.2lf   \r\n GPRINT:cdefb:MAX:max=\"%.2lf\\l\" \r\n LINE:cdefb#999999\r\n AREA:cdefc#006699:\"Average Latency\\: \" \r\n GPRINT:c:LAST:\"%.2lf sec\"\r\n GPRINT:cdefc:MIN:min=%.2lf \r\n GPRINT:cdefc:AVERAGE:avg=%.2lf   \r\n GPRINT:cdefc:MAX:max=\"%.2lf\\l\"  \r\n LINE:cdefc#999999\r\n AREA:a#333366:\"Minimum Latency\\: \" \r\n GPRINT:a:LAST:\"%.2lf sec\"\r\n GPRINT:cdefa:MIN:min=%.2lf \r\n GPRINT:cdefa:AVERAGE:avg=%.2lf   \r\n GPRINT:cdefa:MAX:max=\"%.2lf\\l\" \r\n LINE:cdefa#999999 \r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0\'','',' '),
	(21,'*','tcp_http','nagios',1,0,0,'HTTP Response Time','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:$LABEL1$:GAUGE:1800:U:U DS:$LABEL1$_wn:GAUGE:1800:U:U DS:$LABEL1$_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE\r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE\r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE\r\n CDEF:cdefa=a CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w\r\n CDEF:cdefc=c \r\n AREA:a#33FFFF\r\n AREA:cdefb#00CF00:\"Response Time\\:\"\r\n GPRINT:a:LAST:\"%.4lf Seconds\"  \r\n GPRINT:a:MIN:min=%.2lf\r\n GPRINT:a:AVERAGE:avg=%.2lf\r\n GPRINT:a:MAX:max=\"%.2lf\\l\"\r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\"\r\n GPRINT:cdefw:LAST:\"%.2lf\"\r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\"\r\n GPRINT:cdefc:LAST:\"%.2lf\\l\"  \r\n COMMENT:\"Host\\: HOST\\l\" COMMENT:\"Service\\: SERVICE\"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0\'','',' '),
	(22,'*','local_mysql_database','nagios',1,1,1,'MySQL Threads and Query Stats','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:threads:GAUGE:1800:U:U DS:slow_queries:COUNTER:1800:U:U DS:queries_per_sec:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$VALUE2$:$VALUE3$ 2>&1','\'rrdtool graph - \r\n $LISTSTART$ \r\n   DEF:$DEFLABEL#$:AVERAGE \r\n   CDEF:cdef$CDEFLABEL#$=$CDEFLABEL#$\r\n   LINE2:$CDEFLABEL#$$COLORLABEL#$:$DSLABEL#$\r\n   GPRINT:$CDEFLABEL#$:MIN:min=%.2lf\r\n   GPRINT:$CDEFLABEL#$:AVERAGE:avg=%.2lf\r\n   GPRINT:$CDEFLABEL#$:MAX:max=\"%.2lf\\l\"\r\n $LISTEND$\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120\'','','[\\S+|\\s+]+Threads: (\\d+)  [\\S+|\\s+]+queries: (\\d+)  [\\S+|\\s+]+  \\S+ [\\S+|\\s+]+avg: (\\d+\\.\\d+)'),
	(28,'*','DEFAULT','nagios',1,0,0,'DO NOT REMOVE THIS ENTRY - USE TO DEFINE DEFAULT GRAPHING SETTINGS','','','','rrdtool graph - $LISTSTART$ DEF:$DEFLABEL#$:AVERAGE CDEF:cdef$CDEFLABEL#$=$CDEFLABEL#$ LINE2:$CDEFLABEL#$$COLORLABEL#$:$DSLABEL#$ GPRINT:$CDEFLABEL#$:MIN:min=%.2lf GPRINT:$CDEFLABEL#$:AVERAGE:avg=%.2lf GPRINT:$CDEFLABEL#$:MAX:max=%.2lf  $LISTEND$  -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120','',''),
	(29,'*','local_users','nagios',1,0,0,'Current Users','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:$LABEL1$:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$ 2>&1','rrdtool graph - --imgformat=PNG --slope-mode DEF:a=rrd_source:ds_source_0:AVERAGE  CDEF:cdefa=a  AREA:cdefa#0033CC:\"Number of logged in users\" -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF-Y --height 120','',''),
	(30,'*','local_cpu','nagios',1,0,1,'CPU Utilization','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE \r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE \r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE \r\n CDEF:cdefa=a \r\n CDEF:cdefb=a,0.99,* \r\n AREA:cdefa#7D1B7E:\"Process CPU Utilization\" \r\n GPRINT:cdefa:LAST:Current=%.2lf \r\n GPRINT:cdefa:MIN:min=%.2lf \r\n GPRINT:cdefa:AVERAGE:avg=%.2lf \r\n GPRINT:cdefa:MAX:max=\"%.2lf\\l\" \r\n AREA:cdefb#571B7E: \r\n CDEF:cdefw=w\r\n CDEF:cdefc=c \r\n CDEF:cdefm=cdefc,1.01,* \r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" \r\n GPRINT:cdefw:LAST:\"%.2lf\" \r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\" \r\n GPRINT:cdefc:LAST:\"%.2lf\\l\" \r\n COMMENT:\"Service\\: SERVICE\"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n CDEF:cdefwt=a,cdefw,GT,cdefw,0,IF LINE:cdefwt#000000 CDEF:cdefct=a,cdefc,GT,cdefc,0,IF LINE:cdefct#000000\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y --height 120 --rigid -u 100 -l 0\'','',''),
	(68,'*','tcp_nsca','nagios',1,0,0,'NSCA Response Time','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE\r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE\r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE\r\n CDEF:cdefa=a CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w CDEF:cdefc=c\r\n AREA:a#33FFFF AREA:cdefb#00CF00:\"Response Time\\:\"\r\n GPRINT:a:LAST:\"%.4lf Seconds\"  \r\n GPRINT:a:MIN:min=%.4lf\r\n GPRINT:a:AVERAGE:avg=%.4lf\r\n GPRINT:a:MAX:max=\"%.4lf\\l\"\r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\"\r\n GPRINT:cdefw:LAST:\"%.2lf\"\r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\"\r\n GPRINT:cdefc:LAST:\"%.2lf\\l\"  \r\n COMMENT:\"Host\\: HOST\\l\" COMMENT:\"Service\\: SERVICE\"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0\'','',' '),
	(69,'*','local_swap','nagios',1,0,0,'Swap Utilization','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr $LISTSTART$DS:$LABEL#$:GAUGE:1800:U:U DS:$LABEL#$_wn:GAUGE:1800:U:U DS:$LABEL#$_cr:GAUGE:1800:U:U DS:$LABEL#$_mx:GAUGE:1800:U:U $LISTEND$ RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480\r\n','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$:$MAX1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE \r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE \r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE \r\n DEF:m=\"rrd_source\":ds_source_3:AVERAGE \r\n CDEF:cdefa=a,m,/,100,* \r\n CDEF:cdefw=w\r\n CDEF:cdefc=c\r\n CDEF:cdefm=m \r\n AREA:a#9900FF:\"Swap Free\\: \" \r\n LINE2:a#6600FF: \r\n GPRINT:a:LAST:\"%.2lf MB\\l\" \r\n CDEF:cdefws=a,cdefw,LT,a,0,IF\r\n AREA:cdefws#FFFF00\r\n CDEF:cdefcs=a,cdefc,LT,a,0,IF\r\n AREA:cdefcs#FF0033 \r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\" \r\n GPRINT:cdefw:AVERAGE:\"%.2lf\" \r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\" \r\n GPRINT:cdefc:AVERAGE:\"%.2lf\\l\" \r\n GPRINT:cdefa:AVERAGE:\"Percentage Swap Free\"=%.2lf \r\n GPRINT:cdefm:AVERAGE:\"Total Swap Space=%.2lf\" \r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0\'','',''),
	(77,'*','tcp_gw_listener','nagios',1,0,0,'Foundation Listener Response Time','$HOST$_$SERVICE$.rrd','$RRDTOOL$ create $RRDNAME$ --step 300 --start n-1yr DS:$LABEL1$:GAUGE:1800:U:U DS:$LABEL1$_wn:GAUGE:1800:U:U DS:$LABEL1$_cr:GAUGE:1800:U:U RRA:AVERAGE:0.5:1:8640 RRA:AVERAGE:0.5:12:9480','$RRDTOOL$ update $RRDNAME$ $LASTCHECK$:$VALUE1$:$WARN1$:$CRIT1$ 2>&1','\'rrdtool graph - \r\n DEF:a=\"rrd_source\":ds_source_0:AVERAGE\r\n DEF:w=\"rrd_source\":ds_source_1:AVERAGE\r\n DEF:c=\"rrd_source\":ds_source_2:AVERAGE\r\n CDEF:cdefa=a CDEF:cdefb=a,0.99,*\r\n CDEF:cdefw=w\r\n CDEF:cdefc=c \r\n AREA:a#33FFFF\r\n AREA:cdefb#00CF00:\"Response Time\\:\"\r\n GPRINT:a:LAST:\"%.4lf Seconds\"  \r\n GPRINT:a:MIN:min=%.2lf\r\n GPRINT:a:AVERAGE:avg=%.2lf\r\n GPRINT:a:MAX:max=\"%.2lf\\l\"\r\n LINE2:cdefw#FFFF00:\"Warning Threshold\\:\"\r\n GPRINT:cdefw:LAST:\"%.2lf\"\r\n LINE2:cdefc#FF0033:\"Critical Threshold\\:\"\r\n GPRINT:cdefc:LAST:\"%.2lf\\l\"  \r\n COMMENT:\"Host\\: HOST\\l\" COMMENT:\"Service\\: SERVICE\"\r\n CDEF:cdefws=a,cdefw,GT,a,0,IF AREA:cdefws#FFFF00 CDEF:cdefcs=a,cdefc,GT,a,0,IF AREA:cdefcs#FF0033\r\n -c BACK#FFFFFF -c CANVAS#FFFFFF -c GRID#C0C0C0 -c MGRID#404040 -c ARROW#FFFFFF -Y -l 0\'','',' ');
/*!40000 ALTER TABLE `performanceconfig` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profile_host_profile_service`
--

DROP TABLE IF EXISTS `profile_host_profile_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `profile_host_profile_service` (
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  `serviceprofile_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`hostprofile_id`,`serviceprofile_id`),
  KEY `serviceprofile_id` (`serviceprofile_id`),
  CONSTRAINT `profile_host_profile_service_ibfk_1` FOREIGN KEY (`serviceprofile_id`) REFERENCES `profiles_service` (`serviceprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `profile_host_profile_service_ibfk_2` FOREIGN KEY (`hostprofile_id`) REFERENCES `profiles_host` (`hostprofile_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `profile_host_profile_service`
--

LOCK TABLES `profile_host_profile_service` WRITE;
/*!40000 ALTER TABLE `profile_host_profile_service` DISABLE KEYS */;
INSERT INTO `profile_host_profile_service` VALUES
	(3,2),
	(2,3),
	(1,4),
	(4,5);
/*!40000 ALTER TABLE `profile_host_profile_service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profile_hostgroup`
--

DROP TABLE IF EXISTS `profile_hostgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `profile_hostgroup` (
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`hostprofile_id`,`hostgroup_id`),
  KEY `hostgroup_id` (`hostgroup_id`),
  CONSTRAINT `profile_hostgroup_ibfk_1` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `profile_hostgroup`
--

LOCK TABLES `profile_hostgroup` WRITE;
/*!40000 ALTER TABLE `profile_hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `profile_hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profile_parent`
--

DROP TABLE IF EXISTS `profile_parent`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `profile_parent` (
  `hostprofile_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`hostprofile_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `profile_parent_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `profile_parent`
--

LOCK TABLES `profile_parent` WRITE;
/*!40000 ALTER TABLE `profile_parent` DISABLE KEYS */;
/*!40000 ALTER TABLE `profile_parent` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profiles_host`
--

DROP TABLE IF EXISTS `profiles_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `profiles_host` (
  `hostprofile_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `description` varchar(255) default NULL,
  `host_template_id` smallint(4) unsigned default NULL,
  `host_extinfo_id` smallint(4) unsigned default NULL,
  `host_escalation_id` smallint(4) unsigned default NULL,
  `service_escalation_id` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`hostprofile_id`),
  UNIQUE KEY `name` (`name`),
  KEY `host_extinfo_id` (`host_extinfo_id`),
  KEY `host_escalation_id` (`host_escalation_id`),
  KEY `service_escalation_id` (`service_escalation_id`),
  CONSTRAINT `profiles_host_ibfk_1` FOREIGN KEY (`host_extinfo_id`) REFERENCES `extended_host_info_templates` (`hostextinfo_id`) ON DELETE SET NULL,
  CONSTRAINT `profiles_host_ibfk_2` FOREIGN KEY (`host_escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL,
  CONSTRAINT `profiles_host_ibfk_3` FOREIGN KEY (`service_escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `profiles_host`
--

LOCK TABLES `profiles_host` WRITE;
/*!40000 ALTER TABLE `profiles_host` DISABLE KEYS */;
INSERT INTO `profiles_host` VALUES
	(1,'host-profile-service-ping','Host profile for ping',1,NULL,NULL,NULL,NULL),
	(2,'host-profile-snmp-network','Host Profile for monitoring network devices using snmp',1,NULL,NULL,NULL,NULL),
	(3,'host-profile-ssh-unix','Host Profile for monitoring servers using ssh',1,NULL,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"hosts_select\"><![CDATA[checked]]>\n  </prop>\n  <prop name=\"apply_services\"><![CDATA[replace]]>\n  </prop>\n</data>'),
	(4,'host-profile-cacti-host','Cacti host profile',1,NULL,NULL,NULL,'<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>');
/*!40000 ALTER TABLE `profiles_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profiles_service`
--

DROP TABLE IF EXISTS `profiles_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `profiles_service` (
  `serviceprofile_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` varchar(100) default NULL,
  `data` text,
  PRIMARY KEY  (`serviceprofile_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `profiles_service`
--

LOCK TABLES `profiles_service` WRITE;
/*!40000 ALTER TABLE `profiles_service` DISABLE KEYS */;
INSERT INTO `profiles_service` VALUES
	(2,'ssh-unix','SSH UNIX server generic profile','<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(3,'snmp-network','network_snmp','<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(4,'service-ping','Ping service profile','<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(5,'cacti','Profile containing passive cacti service check','<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>');
/*!40000 ALTER TABLE `profiles_service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service_dependency`
--

DROP TABLE IF EXISTS `service_dependency`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `service_dependency` (
  `id` int(8) unsigned NOT NULL auto_increment,
  `service_id` int(8) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  `depend_on_host_id` int(6) unsigned NOT NULL default '0',
  `template` smallint(4) unsigned NOT NULL default '0',
  `comment` text,
  PRIMARY KEY  (`id`),
  KEY `service_id` (`service_id`),
  KEY `depend_on_host_id` (`depend_on_host_id`),
  CONSTRAINT `service_dependency_ibfk_1` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE,
  CONSTRAINT `service_dependency_ibfk_2` FOREIGN KEY (`depend_on_host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `service_dependency`
--

LOCK TABLES `service_dependency` WRITE;
/*!40000 ALTER TABLE `service_dependency` DISABLE KEYS */;
/*!40000 ALTER TABLE `service_dependency` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service_dependency_templates`
--

DROP TABLE IF EXISTS `service_dependency_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `service_dependency_templates` (
  `id` int(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  `data` text,
  `comment` text,
  PRIMARY KEY  (`id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `service_dependency_templates`
--

LOCK TABLES `service_dependency_templates` WRITE;
/*!40000 ALTER TABLE `service_dependency_templates` DISABLE KEYS */;
/*!40000 ALTER TABLE `service_dependency_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service_instance`
--

DROP TABLE IF EXISTS `service_instance`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `service_instance` (
  `instance_id` int(8) unsigned NOT NULL auto_increment,
  `service_id` int(8) unsigned default NULL,
  `name` varchar(255) NOT NULL,
  `status` tinyint(1) default '0',
  `arguments` varchar(255) default NULL,
  PRIMARY KEY  (`instance_id`),
  KEY `service_id` (`service_id`),
  CONSTRAINT `service_instance_ibfk_1` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `service_instance`
--

LOCK TABLES `service_instance` WRITE;
/*!40000 ALTER TABLE `service_instance` DISABLE KEYS */;
/*!40000 ALTER TABLE `service_instance` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service_names`
--

DROP TABLE IF EXISTS `service_names`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `service_names` (
  `servicename_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) default NULL,
  `description` varchar(100) default NULL,
  `template` smallint(4) unsigned default NULL,
  `check_command` smallint(4) unsigned default NULL,
  `command_line` text,
  `escalation` smallint(4) unsigned default NULL,
  `extinfo` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`servicename_id`),
  UNIQUE KEY `name` (`name`),
  KEY `extinfo` (`extinfo`),
  KEY `escalation` (`escalation`),
  CONSTRAINT `service_names_ibfk_1` FOREIGN KEY (`extinfo`) REFERENCES `extended_service_info_templates` (`serviceextinfo_id`) ON DELETE SET NULL,
  CONSTRAINT `service_names_ibfk_2` FOREIGN KEY (`escalation`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `service_names`
--

LOCK TABLES `service_names` WRITE;
/*!40000 ALTER TABLE `service_names` DISABLE KEYS */;
INSERT INTO `service_names` VALUES
	(1,'*','special use',NULL,NULL,NULL,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(4,'icmp_ping','PING',1,19,'check_ping!100.0,20%!500.0,60%',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(6,'icmp_ping_alive','Ping host to see if it is Alive',1,24,NULL,NULL,1,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(13,'udp_snmp','gwsn-snmp',1,263,NULL,NULL,1,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(14,'snmp_if_1','gwsn-snmp_if',1,32,'check_snmp_if!1',NULL,5,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(15,'snmp_ifbandwidth_1','SNMP_if_bandwidth',1,33,'check_snmp_bandwidth!1',NULL,5,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(16,'snmp_ifoperstatus_1','SNMP_ifoperstatus',1,34,'check_ifoperstatus!1',NULL,5,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(17,'tcp_http','check http server at host',1,11,'check_http!3!5',NULL,1,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(20,'local_mysql_engine','gwsn-local_mysql_engine',1,38,'check_mysql_engine!root!d3v3l0p3r',NULL,1,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(64,'nrpe_disk','check disk on nrpe server',1,66,'check_nrpe_disk!*!80,90',NULL,3,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(169,'tcp_ssh','Check SSH server running at host',1,161,NULL,NULL,1,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(170,'local_disk_root','gwsn-local_disk_root',1,22,'check_local_disk!15%!10%!/',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(173,'local_load','Check the local load on this unix server',1,1,'check_local_load!5,4,3!10,8,6',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(174,'local_memory','gwsn-local_mem',1,41,'check_local_mem!95!99',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(175,'local_mysql_cpu','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!mysql',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(176,'local_mysql_database','gwsn-local_mysql_database',1,37,'check_mysql!monarch!monarch',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(177,'local_mysql_mem','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!mysql',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(178,'local_nagios_latency','Check NSCA port at host',1,44,NULL,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(179,'local_process_gw_listener','Check NSCA port at host',1,45,'check_local_procs_arg!1:1!1:1!groundwork/foundation/container/lib/jboss',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(180,'local_process_mysqld','gwsn-local_mysqld',1,40,'check_local_procs_string!10!20!mysqld',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(181,'local_process_mysqld_safe','gwsn-local_mysqld_safe',1,40,'check_local_procs_string!1!2!mysqld_safe',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(182,'local_process_nagios','Check NSCA port at host',1,43,NULL,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(183,'local_process_snmptrapd','Check NSCA port at host',1,45,'check_local_procs_arg!1:1!1:1!snmptrapd',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(184,'local_process_snmptt','Check NSCA port at host',1,45,'check_local_procs_arg!2:2!2:2!sbin/snmptt',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(185,'local_dir_size_snmptt','Check SNMPTT spool directory size',1,269,'check_dir_size!/usr/local/groundwork/common/var/spool/snmptt!500!1000',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(186,'tcp_gw_listener','Check NSCA port at host',1,270,'check_tcp_gw_listener!5!9',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(187,'tcp_http_port','Check HTTP server on Port at host',1,54,'check_http_port!3!5!80',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(188,'tcp_nsca','Check NSCA port at host',1,42,'check_tcp_nsca!5!9',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"apply_services\"><![CDATA[replace]]>\n  </prop>\n  <prop name=\"apply_check\"><![CDATA[checked]]>\n  </prop>\n</data>\n'),
	(189,'local_users','gwsn-local_users',1,16,'check_local_users!5!20',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(190,'local_cpu_httpd','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!httpd',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(191,'local_cpu_java','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!java',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"apply_services\"><![CDATA[replace]]>\n  </prop>\n  <prop name=\"apply_check\"><![CDATA[checked]]>\n  </prop>\n</data>\n'),
	(192,'local_cpu_mysql','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!mysql',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(193,'local_cpu_nagios','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!nagios',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(194,'local_cpu_perl','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!perl',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(195,'local_cpu_snmptrapd','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!snmptrapd',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(196,'local_cpu_snmptt','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!snmptt',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(197,'local_cpu_syslog-ng','gwsn-local_mysql_engine',1,267,'check_local_proc_cpu!40!50!syslog-ng',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(198,'local_load_stack','Check the local load on this unix server',1,1,'check_local_load!5,4,3!10,8,6',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(199,'local_mem_httpd','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!httpd',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(200,'local_mem_java','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!40!50!java',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"apply_services\"><![CDATA[replace]]>\n  </prop>\n  <prop name=\"apply_check\"><![CDATA[checked]]>\n  </prop>\n</data>\n'),
	(201,'local_mem_mysql','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!mysql',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(202,'local_mem_nagios','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!nagios',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(203,'local_mem_perl','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!perl',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(204,'local_mem_snmptrapd','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!snmptrapd',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(205,'local_mem_snmpttd','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!snmptt',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(206,'local_mem_syslog-ng','gwsn-local_mysql_engine',1,268,'check_local_proc_mem!20!30!syslog-ng',NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(212,'ssh_cpu_proc','gwsn-by_ssh_load',1,272,'check_by_ssh_cpu_proc!<warn>!<crit>!<procname>',NULL,2,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"dependency\"><![CDATA[ssh_depend]]>\n  </prop>\n</data>'),
	(224,'ssh_mem_proc','gwsn-by_ssh_load',1,273,'check_by_ssh_mem_proc!<warn>!<crit>!<procname>',NULL,2,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"dependency\"><![CDATA[ssh_depend]]>\n  </prop>\n</data>'),
	(230,'tcp_mysql','check http server at host',1,20,'check_tcp!3306',NULL,1,'<?xml version=\"1.0\" ?>\n<data>\n</data>'),
	(232,'local_swap','ssh_swap',1,46,'check_local_swap!20%!10%',NULL,3,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"dependency\"><![CDATA[ssh_depend]]>\n  </prop>\n</data>'),
	(233,'cacti',NULL,1,275,'check_msg!3!\"You actively checked a passive service, check your configuration\"',NULL,NULL,'<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n</data>');
/*!40000 ALTER TABLE `service_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service_overrides`
--

DROP TABLE IF EXISTS `service_overrides`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `service_overrides` (
  `service_id` int(8) unsigned NOT NULL default '0',
  `check_period` smallint(4) unsigned default NULL,
  `notification_period` smallint(4) unsigned default NULL,
  `event_handler` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`service_id`),
  CONSTRAINT `service_overrides_ibfk_1` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `service_overrides`
--

LOCK TABLES `service_overrides` WRITE;
/*!40000 ALTER TABLE `service_overrides` DISABLE KEYS */;
INSERT INTO `service_overrides` VALUES
	(1,3,3,NULL,'<?xml version=\"1.0\" ?>\n<data>\n  <prop name=\"freshness_threshold\"><![CDATA[10]]>\n  </prop>\n  <prop name=\"normal_check_interval\"><![CDATA[5]]>\n  </prop>\n  <prop name=\"retry_check_interval\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"max_check_attempts\"><![CDATA[4]]>\n  </prop>\n  <prop name=\"notification_interval\"><![CDATA[960]]>\n  </prop>\n </data>'),
	(2,3,3,NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"max_check_attempts\"><![CDATA[4]]>\n </prop>\n <prop name=\"retry_check_interval\"><![CDATA[1]]>\n </prop>\n <prop name=\"normal_check_interval\"><![CDATA[5]]>\n </prop>\n <prop name=\"notification_interval\"><![CDATA[960]]>\n </prop>\n</data>'),
	(3,3,3,NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"max_check_attempts\"><![CDATA[4]]>\n </prop>\n <prop name=\"retry_check_interval\"><![CDATA[1]]>\n </prop>\n <prop name=\"normal_check_interval\"><![CDATA[5]]>\n </prop>\n <prop name=\"notification_interval\"><![CDATA[960]]>\n </prop>\n</data>'),
	(4,3,3,NULL,'<?xml version=\"1.0\" ?>\n<data>\n <prop name=\"max_check_attempts\"><![CDATA[4]]>\n </prop>\n <prop name=\"retry_check_interval\"><![CDATA[1]]>\n </prop>\n <prop name=\"normal_check_interval\"><![CDATA[5]]>\n </prop>\n <prop name=\"notification_interval\"><![CDATA[960]]>\n </prop>\n</data>');
/*!40000 ALTER TABLE `service_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `service_templates`
--

DROP TABLE IF EXISTS `service_templates`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `service_templates` (
  `servicetemplate_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `parent_id` smallint(4) unsigned default NULL,
  `check_period` smallint(4) unsigned default NULL,
  `notification_period` smallint(4) unsigned default NULL,
  `check_command` smallint(4) unsigned default NULL,
  `command_line` text,
  `event_handler` smallint(4) unsigned default NULL,
  `data` text,
  `comment` text,
  PRIMARY KEY  (`servicetemplate_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `service_templates`
--

LOCK TABLES `service_templates` WRITE;
/*!40000 ALTER TABLE `service_templates` DISABLE KEYS */;
INSERT INTO `service_templates` VALUES
	(1,'generic-service',NULL,3,3,NULL,NULL,NULL,'<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n  <prop name=\"flap_detection_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"retry_check_interval\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"check_freshness\"><![CDATA[-zero-]]>\n  </prop>\n  <prop name=\"event_handler_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"notifications_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"process_perf_data\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"active_checks_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"is_volatile\"><![CDATA[-zero-]]>\n  </prop>\n  <prop name=\"passive_checks_enabled\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"retain_status_information\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"max_check_attempts\"><![CDATA[3]]>\n  </prop>\n  <prop name=\"notification_options\"><![CDATA[u,c,w,r]]>\n  </prop>\n  <prop name=\"retain_nonstatus_information\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"normal_check_interval\"><![CDATA[10]]>\n  </prop>\n  <prop name=\"obsess_over_service\"><![CDATA[1]]>\n  </prop>\n  <prop name=\"notification_interval\"><![CDATA[60]]>\n  </prop>\n</data>','# Generic service definition template - This is NOT a real service, just a template!');
/*!40000 ALTER TABLE `service_templates` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicegroup_service`
--

DROP TABLE IF EXISTS `servicegroup_service`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `servicegroup_service` (
  `servicegroup_id` int(6) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  `service_id` int(8) unsigned NOT NULL default '0',
  PRIMARY KEY  (`servicegroup_id`,`host_id`,`service_id`),
  KEY `host_id` (`host_id`),
  KEY `service_id` (`service_id`),
  CONSTRAINT `servicegroup_service_ibfk_1` FOREIGN KEY (`servicegroup_id`) REFERENCES `servicegroups` (`servicegroup_id`) ON DELETE CASCADE,
  CONSTRAINT `servicegroup_service_ibfk_2` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `servicegroup_service_ibfk_3` FOREIGN KEY (`service_id`) REFERENCES `services` (`service_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `servicegroup_service`
--

LOCK TABLES `servicegroup_service` WRITE;
/*!40000 ALTER TABLE `servicegroup_service` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicegroup_service` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicegroups`
--

DROP TABLE IF EXISTS `servicegroups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `servicegroups` (
  `servicegroup_id` int(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `alias` varchar(255) NOT NULL default '',
  `escalation_id` smallint(4) unsigned default NULL,
  `comment` text,
  `notes` varchar(4096) default NULL,
  PRIMARY KEY  (`servicegroup_id`),
  UNIQUE KEY `name` (`name`),
  KEY `escalation_id` (`escalation_id`),
  CONSTRAINT `servicegroups_ibfk_1` FOREIGN KEY (`escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `servicegroups`
--

LOCK TABLES `servicegroups` WRITE;
/*!40000 ALTER TABLE `servicegroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicegroups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicename_dependency`
--

DROP TABLE IF EXISTS `servicename_dependency`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `servicename_dependency` (
  `id` smallint(4) unsigned NOT NULL auto_increment,
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  `depend_on_host_id` int(6) unsigned default NULL,
  `template` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`id`),
  KEY `servicename_id` (`servicename_id`),
  KEY `depend_on_host_id` (`depend_on_host_id`),
  CONSTRAINT `servicename_dependency_ibfk_1` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE,
  CONSTRAINT `servicename_dependency_ibfk_2` FOREIGN KEY (`depend_on_host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `servicename_dependency`
--

LOCK TABLES `servicename_dependency` WRITE;
/*!40000 ALTER TABLE `servicename_dependency` DISABLE KEYS */;
/*!40000 ALTER TABLE `servicename_dependency` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `servicename_overrides`
--

DROP TABLE IF EXISTS `servicename_overrides`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `servicename_overrides` (
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  `check_period` smallint(4) unsigned default NULL,
  `notification_period` smallint(4) unsigned default NULL,
  `event_handler` smallint(4) unsigned default NULL,
  `data` text,
  PRIMARY KEY  (`servicename_id`),
  CONSTRAINT `servicename_overrides_ibfk_1` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `servicename_overrides`
--

LOCK TABLES `servicename_overrides` WRITE;
/*!40000 ALTER TABLE `servicename_overrides` DISABLE KEYS */;
INSERT INTO `servicename_overrides` VALUES
	(16,NULL,NULL,NULL,'<?xml version=\"1.0\" ?>\n<data>\n </data>'),
	(233,1,NULL,NULL,'<?xml version=\"1.0\" encoding=\"iso-8859-1\" ?>\n<data>\n  <prop name=\"active_checks_enabled\"><![CDATA[-zero-]]>\n  </prop>\n  <prop name=\"max_check_attempts\"><![CDATA[1]]>\n  </prop>\n</data>');
/*!40000 ALTER TABLE `servicename_overrides` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `serviceprofile`
--

DROP TABLE IF EXISTS `serviceprofile`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `serviceprofile` (
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  `serviceprofile_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`servicename_id`,`serviceprofile_id`),
  KEY `serviceprofile_id` (`serviceprofile_id`),
  CONSTRAINT `serviceprofile_ibfk_1` FOREIGN KEY (`servicename_id`) REFERENCES `service_names` (`servicename_id`) ON DELETE CASCADE,
  CONSTRAINT `serviceprofile_ibfk_2` FOREIGN KEY (`serviceprofile_id`) REFERENCES `profiles_service` (`serviceprofile_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `serviceprofile`
--

LOCK TABLES `serviceprofile` WRITE;
/*!40000 ALTER TABLE `serviceprofile` DISABLE KEYS */;
INSERT INTO `serviceprofile` VALUES
	(169,2),
	(13,3),
	(14,3),
	(15,3),
	(16,3),
	(6,4),
	(6,5),
	(233,5);
/*!40000 ALTER TABLE `serviceprofile` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `serviceprofile_host`
--

DROP TABLE IF EXISTS `serviceprofile_host`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `serviceprofile_host` (
  `serviceprofile_id` smallint(4) unsigned NOT NULL default '0',
  `host_id` int(6) unsigned NOT NULL default '0',
  PRIMARY KEY  (`serviceprofile_id`,`host_id`),
  KEY `host_id` (`host_id`),
  CONSTRAINT `serviceprofile_host_ibfk_1` FOREIGN KEY (`serviceprofile_id`) REFERENCES `profiles_service` (`serviceprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `serviceprofile_host_ibfk_2` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `serviceprofile_host`
--

LOCK TABLES `serviceprofile_host` WRITE;
/*!40000 ALTER TABLE `serviceprofile_host` DISABLE KEYS */;
/*!40000 ALTER TABLE `serviceprofile_host` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `serviceprofile_hostgroup`
--

DROP TABLE IF EXISTS `serviceprofile_hostgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `serviceprofile_hostgroup` (
  `serviceprofile_id` smallint(4) unsigned NOT NULL default '0',
  `hostgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`serviceprofile_id`,`hostgroup_id`),
  KEY `hostgroup_id` (`hostgroup_id`),
  CONSTRAINT `serviceprofile_hostgroup_ibfk_1` FOREIGN KEY (`serviceprofile_id`) REFERENCES `profiles_service` (`serviceprofile_id`) ON DELETE CASCADE,
  CONSTRAINT `serviceprofile_hostgroup_ibfk_2` FOREIGN KEY (`hostgroup_id`) REFERENCES `hostgroups` (`hostgroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `serviceprofile_hostgroup`
--

LOCK TABLES `serviceprofile_hostgroup` WRITE;
/*!40000 ALTER TABLE `serviceprofile_hostgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `serviceprofile_hostgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `services`
--

DROP TABLE IF EXISTS `services`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `services` (
  `service_id` int(8) unsigned NOT NULL auto_increment,
  `host_id` int(6) unsigned NOT NULL default '0',
  `servicename_id` smallint(4) unsigned NOT NULL default '0',
  `servicetemplate_id` smallint(4) unsigned default NULL,
  `serviceextinfo_id` smallint(4) unsigned default NULL,
  `escalation_id` smallint(4) unsigned default NULL,
  `status` tinyint(1) default NULL,
  `check_command` smallint(4) unsigned default NULL,
  `command_line` text,
  `comment` text,
  `notes` varchar(4096) default NULL,
  PRIMARY KEY  (`service_id`),
  KEY `host_id` (`host_id`),
  KEY `serviceextinfo_id` (`serviceextinfo_id`),
  KEY `escalation_id` (`escalation_id`),
  CONSTRAINT `services_ibfk_1` FOREIGN KEY (`host_id`) REFERENCES `hosts` (`host_id`) ON DELETE CASCADE,
  CONSTRAINT `services_ibfk_2` FOREIGN KEY (`serviceextinfo_id`) REFERENCES `extended_service_info_templates` (`serviceextinfo_id`) ON DELETE SET NULL,
  CONSTRAINT `services_ibfk_3` FOREIGN KEY (`escalation_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `services`
--

LOCK TABLES `services` WRITE;
/*!40000 ALTER TABLE `services` DISABLE KEYS */;
INSERT INTO `services` VALUES
	(159,1,170,1,NULL,NULL,1,22,'check_local_disk!15%!10%!/',NULL,NULL),
	(161,1,206,1,NULL,NULL,1,268,'check_local_proc_mem!20!30!syslog-ng',NULL,NULL),
	(162,1,188,1,NULL,NULL,1,42,'check_tcp_nsca!5!9',NULL,NULL),
	(163,1,193,1,NULL,NULL,1,267,'check_local_proc_cpu!40!50!nagios',NULL,NULL),
	(164,1,17,1,1,NULL,1,11,'check_http!3!5',NULL,NULL),
	(165,1,200,1,NULL,NULL,1,268,'check_local_proc_mem!40!50!java',NULL,NULL),
	(166,1,180,1,NULL,NULL,1,40,'check_local_procs_string!10!20!mysqld',NULL,NULL),
	(167,1,179,1,NULL,NULL,1,45,'check_local_procs_arg!1:1!1:1!groundwork/foundation/container/lib/jboss',NULL,NULL),
	(168,1,186,1,NULL,NULL,1,270,'check_tcp_gw_listener!5!9',NULL,NULL),
	(169,1,190,1,NULL,NULL,1,267,'check_local_proc_cpu!40!50!httpd',NULL,NULL),
	(170,1,182,1,NULL,NULL,1,43,NULL,NULL,NULL),
	(171,1,194,1,NULL,NULL,1,267,'check_local_proc_cpu!40!50!perl',NULL,NULL),
	(172,1,192,1,NULL,NULL,1,267,'check_local_proc_cpu!40!50!mysql',NULL,NULL),
	(173,1,202,1,NULL,NULL,1,268,'check_local_proc_mem!20!30!nagios',NULL,NULL),
	(175,1,191,1,NULL,NULL,1,267,'check_local_proc_cpu!40!50!java',NULL,NULL),
	(176,1,201,1,NULL,NULL,1,268,'check_local_proc_mem!20!30!mysql',NULL,NULL),
	(177,1,232,1,3,NULL,1,46,'check_local_swap!20%!10%',NULL,NULL),
	(178,1,178,1,NULL,NULL,1,44,NULL,NULL,NULL),
	(179,1,189,1,NULL,NULL,1,16,'check_local_users!5!20',NULL,NULL),
	(180,1,181,1,NULL,NULL,1,40,'check_local_procs_string!1!2!mysqld_safe',NULL,NULL),
	(182,1,174,1,NULL,NULL,1,41,'check_local_mem!95!99',NULL,NULL),
	(183,1,197,1,NULL,NULL,1,267,'check_local_proc_cpu!40!50!syslog-ng',NULL,NULL),
	(184,1,203,1,NULL,NULL,1,268,'check_local_proc_mem!20!30!perl',NULL,NULL),
	(187,1,199,1,NULL,NULL,1,268,'check_local_proc_mem!20!30!httpd',NULL,NULL),
	(188,1,176,1,NULL,NULL,1,37,'check_mysql!monarch!monarch',NULL,NULL),
	(189,1,173,1,NULL,NULL,1,1,'check_local_load!5,4,3!10,8,6',NULL,NULL);
/*!40000 ALTER TABLE `services` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `sessions` (
  `id` char(32) NOT NULL,
  `a_session` text NOT NULL,
  UNIQUE KEY `id` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `sessions`
--

LOCK TABLES `sessions` WRITE;
UNLOCK TABLES;

--
-- Table structure for table `setup`
--

DROP TABLE IF EXISTS `setup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `setup` (
  `name` varchar(255) NOT NULL default '',
  `type` varchar(50) default NULL,
  `value` text,
  PRIMARY KEY  (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `setup`
--

LOCK TABLES `setup` WRITE;
/*!40000 ALTER TABLE `setup` DISABLE KEYS */;
INSERT INTO `setup` VALUES
	('accept_passive_host_checks','nagios','1'),
	('accept_passive_service_checks','nagios','1'),
	('admin_email','nagios','nagios@localhost'),
	('admin_pager','nagios','pagenagios@localhost'),
	('authorized_for_all_hosts','nagios_cgi','admin,guest'),
	('authorized_for_all_host_commands','nagios_cgi','admin'),
	('authorized_for_all_services','nagios_cgi','admin,guest'),
	('authorized_for_all_service_commands','nagios_cgi','admin'),
	('authorized_for_configuration_information','nagios_cgi','admin,jdoe'),
	('authorized_for_system_commands','nagios_cgi','admin'),
	('authorized_for_system_information','nagios_cgi','admin,theboss,jdoe'),
	('auto_reschedule_checks','nagios',NULL),
	('auto_rescheduling_interval','nagios','30'),
	('auto_rescheduling_window','nagios','180'),
	('backup_dir','config','/usr/local/groundwork/monarch/backup'),
	('broker_module','nagios','/usr/local/nagios/lib/libbronx.so'),
	('cached_host_check_horizon','nagios','15'),
	('cached_service_check_horizon','nagios','15'),
	('cgi_bin','config','0'),
	('check_external_commands','nagios','1'),
	('check_for_orphaned_services','nagios',NULL),
	('check_host_freshness','nagios',NULL),
	('check_result_path','nagios','/usr/local/nagios/var/checkresults'),
	('check_result_reaper_frequency','nagios','10'),
	('check_service_freshness','nagios',NULL),
	('child_processes_fork_twice','nagios',NULL),
	('commands','file','26'),
	('command_check_interval','nagios','-1'),
	('command_file','nagios','/usr/local/nagios/var/spool/nagios.cmd'),
	('contactgroup','monarch_ez','nagiosadmin'),
	('contactgroups','file','30'),
	('contacts','file','31'),
	('contact_template','monarch_ez','generic-contact-2'),
	('contact_templates','file','29'),
	('date_format','nagios','us'),
	('default_statusmap_layout','nagios_cgi','5'),
	('default_statuswrl_layout','nagios_cgi','2'),
	('default_user_name','nagios_cgi','admin'),
	('doc_root','config','0'),
	('enable_environment_macros','nagios',NULL),
	('enable_event_handlers','nagios','1'),
	('enable_externals','config','0'),
	('enable_flap_detection','nagios',NULL),
	('enable_groups','config','0'),
	('enable_notifications','nagios',NULL),
	('escalations','file','35'),
	('escalation_templates','file','18'),
	('event_broker_options','nagios','-1'),
	('event_handler_timeout','nagios','30'),
	('execute_host_checks','nagios','1'),
	('execute_service_checks','nagios','1'),
	('extended_host_info','file','36'),
	('extended_host_info_templates','file','22'),
	('extended_service_info','file','21'),
	('extended_service_info_templates','file','20'),
	('external_command_buffer_slots','nagios',NULL),
	('free_child_process_memory','nagios',NULL),
	('freshness_check_interval','nagios','60'),
	('global_host_event_handler','nagios',NULL),
	('global_service_event_handler','nagios',NULL),
	('high_host_flap_threshold','nagios','50.0'),
	('high_service_flap_threshold','nagios','50.0'),
	('hostgroups','file','33'),
	('hosts','file','13'),
	('host_check_timeout','nagios','30'),
	('host_dependencies','file','23'),
	('host_down_sound','nagios_cgi',NULL),
	('host_freshness_check_interval','nagios','60'),
	('host_inter_check_delay_method','nagios','s'),
	('host_perfdata_command','nagios',NULL),
	('host_perfdata_file','nagios',NULL),
	('host_perfdata_file_mode','nagios','w'),
	('host_perfdata_file_processing_command','nagios',NULL),
	('host_perfdata_file_processing_interval','nagios',NULL),
	('host_perfdata_file_template','nagios',NULL),
	('host_profile','monarch_ez','host-profile-service-ping'),
	('host_templates','file','32'),
	('host_unreachable_sound','nagios_cgi',NULL),
	('illegal_macro_output_chars','nagios','`~$&|\"<>'),
	('illegal_object_name_chars','nagios','`~!$%^&*|\'\"<>?,()\'='),
	('interval_length','nagios','60'),
	('is_portal','config','1'),
	('lock_author_names','nagios_cgi',NULL),
	('lock_file','nagios','/usr/local/nagios/var/nagios.lock'),
	('login_authentication','','none'),
	('log_archive_path','nagios','/usr/local/nagios/var/archives'),
	('log_event_handlers','nagios','1'),
	('log_external_commands','nagios','1'),
	('log_file','nagios','/usr/local/nagios/var/nagios.log'),
	('log_host_retries','nagios','1'),
	('log_initial_states','nagios',NULL),
	('log_notifications','nagios','1'),
	('log_passive_checks','nagios','1'),
	('log_passive_service_checks','nagios',NULL),
	('log_rotation_method','nagios','d'),
	('log_service_retries','nagios','1'),
	('low_host_flap_threshold','nagios','25.0'),
	('low_service_flap_threshold','nagios','25.0'),
	('max_check_result_file_age','nagios',NULL),
	('max_check_result_reaper_time','nagios',NULL),
	('max_concurrent_checks','nagios','100'),
	('max_host_check_spread','nagios','30'),
	('max_service_check_spread','nagios','30'),
	('max_tree_nodes','config','3000'),
	('misccommands','file','27'),
	('monarch_home','config','/usr/local/groundwork/monarch'),
	('monarch_version','config','3.7'),
	('nagios_bin','config','/usr/local/nagios/bin'),
	('nagios_check_command','nagios_cgi','/usr/local/nagios/libexec/check_nagios /usr/local/nagios/var/status.log 5 \'/usr/local/nagios/bin/.nagios.bin\''),
	('nagios_etc','config','/usr/local/nagios/etc'),
	('nagios_group','nagios','nagios'),
	('nagios_user','nagios','nagios'),
	('nagios_version','config','3.x'),
	('notification_timeout','nagios','30'),
	('object_cache_file','nagios','/usr/local/nagios/var/objects.cache'),
	('obsess_over_hosts','nagios',NULL),
	('obsess_over_services','nagios',NULL),
	('ochp_command','nagios',NULL),
	('ochp_timeout','nagios','5'),
	('ocsp_command','nagios',NULL),
	('ocsp_timeout','nagios','5'),
	('other_host_inter_check_delay_method','nagios',NULL),
	('other_service_interleave_factor','nagios',NULL),
	('other_service_inter_check_delay_method','nagios',NULL),
	('passive_host_checks_are_soft','nagios',NULL),
	('perfdata_timeout','nagios','60'),
	('perflogbug_workaround_removed','nagios','1'),
	('physical_html_path','nagios_cgi','/usr/local/nagios/share'),
	('ping_syntax','nagios_cgi','/bin/ping -n -U -c 5 $HOSTADDRESS$'),
	('precached_object_file','nagios','/usr/local/nagios/var/objects.precache'),
	('process_performance_data','nagios','1'),
	('refresh_rate','nagios_cgi','90'),
	('resource_file','nagios','/usr/local/nagios/etc/resource.cfg'),
	('resource_label1','resource','plugin directory'),
	('resource_label10','resource',''),
	('resource_label11','resource',''),
	('resource_label12','resource',''),
	('resource_label13','resource','sendEmail smtp mail relay option (-s) value'),
	('resource_label14','resource',''),
	('resource_label15','resource',''),
	('resource_label16','resource',''),
	('resource_label17','resource','default check_by_ssh remote user name for all SSH checks'),
	('resource_label18','resource',''),
	('resource_label19','resource','NSClient TCP Port'),
	('resource_label2','resource','event handler scripts directory'),
	('resource_label20','resource',''),
	('resource_label21','resource','GroundWork Proxy Server IP'),
	('resource_label22','resource','default plugin subdirectory on remote hosts, relative to the home directory of the user you SSH in as'),
	('resource_label23','resource',''),
	('resource_label24','resource',''),
	('resource_label25','resource',''),
	('resource_label26','resource',''),
	('resource_label27','resource',''),
	('resource_label28','resource',''),
	('resource_label29','resource',''),
	('resource_label3','resource','plugin timeout'),
	('resource_label30','resource',''),
	('resource_label31','resource',''),
	('resource_label32','resource','GroundWork Server fully qualified hostname'),
	('resource_label4','resource','NSClient password'),
	('resource_label5','resource',''),
	('resource_label6','resource','default MySQL password for GroundWork databases'),
	('resource_label7','resource','SNMP community string'),
	('resource_label8','resource','alternate SNMP community string'),
	('resource_label9','resource',''),
	('retain_state_information','nagios','1'),
	('retention_update_interval','nagios','60'),
	('servicegroups','file','15'),
	('services','file','19'),
	('service_check_timeout','nagios','60'),
	('service_critical_sound','nagios_cgi',NULL),
	('service_dependency','file','17'),
	('service_dependency_templates','file','16'),
	('service_interleave_factor','nagios','s'),
	('service_inter_check_delay_method','nagios','s'),
	('service_perfdata_command','nagios',NULL),
	('service_perfdata_file','nagios','/usr/local/nagios/var/service-perfdata.dat'),
	('service_perfdata_file_mode','nagios','a'),
	('service_perfdata_file_processing_command','nagios','launch_perfdata_process'),
	('service_perfdata_file_processing_interval','nagios','300'),
	('service_perfdata_file_template','nagios','$LASTSERVICECHECK$\\t$HOSTNAME$\\t$SERVICEDESC$\\t$SERVICEOUTPUT$\\t$SERVICEPERFDATA$'),
	('service_templates','file','34'),
	('service_unknown_sound','nagios_cgi',NULL),
	('service_warning_sound','nagios_cgi',NULL),
	('session_timeout','','3600'),
	('show_context_help','nagios_cgi','1'),
	('sleep_time','nagios','1'),
	('soft_state_dependencies','nagios',NULL),
	('state_retention_file','nagios','/usr/local/nagios/var/nagiosstatus.sav'),
	('statusmap_background_image','nagios_cgi','states.png'),
	('statuswrl_include','nagios_cgi','myworld.wrl'),
	('status_file','nagios','/usr/local/nagios/var/status.log'),
	('status_update_interval','nagios','15'),
	('super_user_password','',''),
	('task','nagios','view_edit'),
	('temp_file','nagios','/usr/local/nagios/var/nagios.tmp'),
	('time_periods','file','28'),
	('translate_passive_host_checks','nagios',NULL),
	('upload_dir','config','/tmp'),
	('url_html_path','nagios_cgi','/nagios'),
	('user1','resource','/usr/local/nagios/libexec'),
	('user10','resource',''),
	('user11','resource',''),
	('user12','resource',''),
	('user13','resource','127.0.0.1'),
	('user14','resource',''),
	('user15','resource',''),
	('user16','resource',''),
	('user17','resource','nagios'),
	('user18','resource',''),
	('user19','resource','1248'),
	('user2','resource','/usr/local/nagios/eventhandlers'),
	('user20','resource',''),
	('user21','resource','127.0.0.1'),
	('user22','resource','libexec'),
	('user23','resource',''),
	('user24','resource',''),
	('user25','resource',''),
	('user26','resource',''),
	('user27','resource',''),
	('user28','resource',''),
	('user29','resource',''),
	('user3','resource','60'),
	('user30','resource',''),
	('user31','resource',''),
	('user32','resource','USER32_GROUNDWORK_SERVER'),
	('user4','resource','somepassword'),
	('user5','resource',''),
	('user6','resource','gwrk'),
	('user7','resource','public'),
	('user8','resource','itgwrk'),
	('user9','resource',''),
	('use_aggressive_host_checking','nagios',NULL),
	('use_authentication','nagios_cgi','1'),
	('use_large_installation_tweaks','nagios','1'),
	('use_regexp_matching','nagios',NULL),
	('use_retained_program_state','nagios','1'),
	('use_retained_scheduling_info','nagios','1'),
	('use_syslog','nagios',NULL),
	('use_true_regexp_matching','nagios',NULL);
/*!40000 ALTER TABLE `setup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stage_host_hostgroups`
--

DROP TABLE IF EXISTS `stage_host_hostgroups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `stage_host_hostgroups` (
  `name` varchar(255) NOT NULL default '',
  `user_acct` varchar(50) NOT NULL default '',
  `hostgroup` varchar(50) NOT NULL default '',
  PRIMARY KEY  (`name`,`user_acct`,`hostgroup`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `stage_host_hostgroups`
--

LOCK TABLES `stage_host_hostgroups` WRITE;
/*!40000 ALTER TABLE `stage_host_hostgroups` DISABLE KEYS */;
/*!40000 ALTER TABLE `stage_host_hostgroups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stage_host_services`
--

DROP TABLE IF EXISTS `stage_host_services`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `stage_host_services` (
  `name` varchar(255) NOT NULL default '',
  `user_acct` varchar(50) NOT NULL default '',
  `host` varchar(50) NOT NULL default '',
  `type` varchar(20) default NULL,
  `status` tinyint(1) default NULL,
  `service_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`name`,`user_acct`,`host`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `stage_host_services`
--

LOCK TABLES `stage_host_services` WRITE;
/*!40000 ALTER TABLE `stage_host_services` DISABLE KEYS */;
/*!40000 ALTER TABLE `stage_host_services` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stage_hosts`
--

DROP TABLE IF EXISTS `stage_hosts`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `stage_hosts` (
  `name` varchar(255) NOT NULL default '',
  `user_acct` varchar(50) NOT NULL default '',
  `type` varchar(20) default NULL,
  `status` tinyint(1) default NULL,
  `alias` varchar(255) default NULL,
  `address` varchar(255) default NULL,
  `os` varchar(50) default NULL,
  `hostprofile` varchar(50) default NULL,
  `serviceprofile` varchar(50) default NULL,
  `info` varchar(50) default NULL,
  `notes` varchar(4096) default NULL,
  PRIMARY KEY  (`name`,`user_acct`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `stage_hosts`
--

LOCK TABLES `stage_hosts` WRITE;
/*!40000 ALTER TABLE `stage_hosts` DISABLE KEYS */;
/*!40000 ALTER TABLE `stage_hosts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `stage_other`
--

DROP TABLE IF EXISTS `stage_other`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `stage_other` (
  `name` varchar(255) NOT NULL default '',
  `type` varchar(50) NOT NULL default '',
  `parent` varchar(255) NOT NULL default '',
  `data` text,
  `comment` text,
  PRIMARY KEY  (`name`,`type`,`parent`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `stage_other`
--

LOCK TABLES `stage_other` WRITE;
/*!40000 ALTER TABLE `stage_other` DISABLE KEYS */;
/*!40000 ALTER TABLE `stage_other` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `time_period_exclude`
--

DROP TABLE IF EXISTS `time_period_exclude`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `time_period_exclude` (
  `timeperiod_id` smallint(4) unsigned NOT NULL default '0',
  `exclude_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`timeperiod_id`,`exclude_id`),
  KEY `exclude_id` (`exclude_id`),
  CONSTRAINT `time_period_exclude_ibfk_1` FOREIGN KEY (`timeperiod_id`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE CASCADE,
  CONSTRAINT `time_period_exclude_ibfk_2` FOREIGN KEY (`exclude_id`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `time_period_exclude`
--

LOCK TABLES `time_period_exclude` WRITE;
/*!40000 ALTER TABLE `time_period_exclude` DISABLE KEYS */;
/*!40000 ALTER TABLE `time_period_exclude` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `time_period_property`
--

DROP TABLE IF EXISTS `time_period_property`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `time_period_property` (
  `timeperiod_id` smallint(4) unsigned NOT NULL default '0',
  `name` varchar(255) NOT NULL default '',
  `type` varchar(255) default NULL,
  `value` varchar(255) default NULL,
  `comment` varchar(255) default NULL,
  PRIMARY KEY  (`timeperiod_id`,`name`),
  CONSTRAINT `time_period_property_ibfk_1` FOREIGN KEY (`timeperiod_id`) REFERENCES `time_periods` (`timeperiod_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `time_period_property`
--

LOCK TABLES `time_period_property` WRITE;
/*!40000 ALTER TABLE `time_period_property` DISABLE KEYS */;
INSERT INTO `time_period_property` VALUES
	(2,'friday','weekday','09:00-17:00',''),
	(2,'monday','weekday','09:00-17:00',''),
	(2,'thursday','weekday','09:00-17:00',''),
	(2,'tuesday','weekday','09:00-17:00',''),
	(2,'wednesday','weekday','09:00-17:00',''),
	(3,'friday','weekday','00:00-24:00',''),
	(3,'monday','weekday','00:00-24:00',''),
	(3,'saturday','weekday','00:00-24:00',''),
	(3,'sunday','weekday','00:00-24:00',''),
	(3,'thursday','weekday','00:00-24:00',''),
	(3,'tuesday','weekday','00:00-24:00',''),
	(3,'wednesday','weekday','00:00-24:00',''),
	(4,'friday','weekday','00:00-09:00,17:00-24:00',''),
	(4,'monday','weekday','00:00-09:00,17:00-24:00',''),
	(4,'saturday','weekday','00:00-24:00',''),
	(4,'sunday','weekday','00:00-24:00',''),
	(4,'thursday','weekday','00:00-09:00,17:00-24:00',''),
	(4,'tuesday','weekday','00:00-09:00,17:00-24:00',''),
	(4,'wednesday','weekday','00:00-09:00,17:00-24:00','');
/*!40000 ALTER TABLE `time_period_property` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `time_periods`
--

DROP TABLE IF EXISTS `time_periods`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `time_periods` (
  `timeperiod_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `alias` varchar(255) NOT NULL default '',
  `comment` text,
  PRIMARY KEY  (`timeperiod_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `time_periods`
--

LOCK TABLES `time_periods` WRITE;
/*!40000 ALTER TABLE `time_periods` DISABLE KEYS */;
INSERT INTO `time_periods` VALUES
	(1,'none','No Time Is A Good Time','\'none\' timeperiod definition'),
	(2,'workhours','\"Normal\" Working Hours','\'workhours\' timeperiod definition'),
	(3,'24x7','24 Hours A Day, 7 Days A Week','All day, every day.'),
	(4,'nonworkhours','Non-Work Hours','\'nonworkhours\' timeperiod definition');
/*!40000 ALTER TABLE `time_periods` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tree_template_contactgroup`
--

DROP TABLE IF EXISTS `tree_template_contactgroup`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `tree_template_contactgroup` (
  `tree_id` smallint(4) unsigned NOT NULL default '0',
  `template_id` smallint(4) unsigned NOT NULL default '0',
  `contactgroup_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`tree_id`,`template_id`,`contactgroup_id`),
  KEY `contactgroup_id` (`contactgroup_id`),
  KEY `template_id` (`template_id`),
  CONSTRAINT `tree_template_contactgroup_ibfk_1` FOREIGN KEY (`contactgroup_id`) REFERENCES `contactgroups` (`contactgroup_id`) ON DELETE CASCADE,
  CONSTRAINT `tree_template_contactgroup_ibfk_2` FOREIGN KEY (`template_id`) REFERENCES `escalation_templates` (`template_id`) ON DELETE CASCADE,
  CONSTRAINT `tree_template_contactgroup_ibfk_3` FOREIGN KEY (`tree_id`) REFERENCES `escalation_trees` (`tree_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `tree_template_contactgroup`
--

LOCK TABLES `tree_template_contactgroup` WRITE;
/*!40000 ALTER TABLE `tree_template_contactgroup` DISABLE KEYS */;
/*!40000 ALTER TABLE `tree_template_contactgroup` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_group`
--

DROP TABLE IF EXISTS `user_group`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `user_group` (
  `usergroup_id` smallint(4) unsigned NOT NULL default '0',
  `user_id` smallint(4) unsigned NOT NULL default '0',
  PRIMARY KEY  (`usergroup_id`,`user_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `user_group_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `user_group_ibfk_2` FOREIGN KEY (`usergroup_id`) REFERENCES `user_groups` (`usergroup_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `user_group`
--

LOCK TABLES `user_group` WRITE;
/*!40000 ALTER TABLE `user_group` DISABLE KEYS */;
INSERT INTO `user_group` VALUES
	(1,1),
	(1,2);
/*!40000 ALTER TABLE `user_group` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_groups`
--

DROP TABLE IF EXISTS `user_groups`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `user_groups` (
  `usergroup_id` smallint(4) unsigned NOT NULL auto_increment,
  `name` varchar(255) NOT NULL default '',
  `description` varchar(100) default NULL,
  PRIMARY KEY  (`usergroup_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `user_groups`
--

LOCK TABLES `user_groups` WRITE;
/*!40000 ALTER TABLE `user_groups` DISABLE KEYS */;
INSERT INTO `user_groups` VALUES
	(1,'super_users','System defined group granted complete access.');
/*!40000 ALTER TABLE `user_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `users` (
  `user_id` smallint(4) unsigned NOT NULL auto_increment,
  `user_acct` varchar(20) NOT NULL default '',
  `user_name` varchar(255) NOT NULL default '',
  `password` varchar(20) NOT NULL default '',
  `session` varchar(255) default NULL,
  PRIMARY KEY  (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES
	(1,'super_user','Super User Account','Py.Z3VRXrRE3k','4ce50937286796d7a3ddcd978f0ea459'),
	(2,'admin','admin','','47cd4fa89c4fc37ba117dbf1fe8a7e7a');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-08-24  0:02:48
