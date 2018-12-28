#
# Makefile for Monarch
#
# The main targets that can be executed directly are:
#
#     clean     remove built files from a configuration
#     all       build all configurations
#
# Copyright (c) 2007-2018 Groundwork Open Source
#
#	2018-12-11 RW;	Created.
#

# Environment
MKDIR = mkdir
CP = cp
CC = gcc
CHOWN = chown
CHMOD = chmod
SED = sed

# Nagois install
NAGIOS_BASE = /usr/local/nagios

# Apache2 conf/sites/suexec configuration
APACHE2_PORTSCONF = /etc/apache2/ports.conf
APACHE2_DEFAULTSITECONF = /etc/apache2/sites-enabled/000-default.conf
APACHE2_SITES = /etc/apache2/sites-enabled
APACHE2_SUEXEC = /etc/apache2/suexec/www-data

# Groundwork Monarch install
MONARCH_BASE = /usr/local/groundwork/monarch

# Groundwork config install
CONFIG_BASE = /usr/local/groundwork/config

# Target dir
TARGETDIR = dist

# Let's make the default make target always safe to run.
#
default	: help

help :
	@echo ""
	@echo "Primary build targets:"
	@echo ""
	@echo "    make help"
	@echo "    make all"
	@echo "    make clean"
	@echo ""
	@echo "Primary install targets:"
	@echo "(must be run as root or nagios)"
	@echo ""
	@echo "    make install"
	@echo "    make install-nagios"
	@echo ""

all	: ${TARGETDIR}/nagios_reload ${TARGETDIR}/nmap_scan_one ${TARGETDIR}/monarch_as_nagios

${TARGETDIR}/nagios_reload :
	${MKDIR} -p ${TARGETDIR}
	$(CC) src/nagios_restart/nagios_restarter.c -o ${TARGETDIR}/nagios_reload

${TARGETDIR}/nmap_scan_one :
	${MKDIR} -p ${TARGETDIR}
	$(CC) src/nmap_scan/nmap_scan.c -o ${TARGETDIR}/nmap_scan_one

${TARGETDIR}/monarch_as_nagios :
	${MKDIR} -p ${TARGETDIR}
	$(CC) src/monarch_nagios/monarch_as_nagios.c -o ${TARGETDIR}/monarch_as_nagios

install : all
	@if [ "`id -u`" -ne 0 -a "`id -un`" != nagios ]; then \
	    echo "ERROR:  You must be either root or nagios to install Monarch."; \
	    exit 1; \
	fi
	${RM} -r ${MONARCH_BASE}
	${MKDIR} -p ${MONARCH_BASE}
	${MKDIR} ${MONARCH_BASE}/distribution
	${MKDIR} ${MONARCH_BASE}/workspace
	${MKDIR} ${MONARCH_BASE}/backup
	${MKDIR} ${MONARCH_BASE}/var
	${CP} -pr automation bin cgi-bin htdocs lib etc profiles ${MONARCH_BASE}
	${MKDIR} ${MONARCH_BASE}/htdocs/gdma
	${CP} -p ${TARGETDIR}/nagios_reload ${MONARCH_BASE}/bin
	${CP} -p ${TARGETDIR}/nmap_scan_one ${MONARCH_BASE}/bin
	${CP} -p ${TARGETDIR}/monarch_as_nagios ${MONARCH_BASE}/bin
	${CHOWN} nagios:nagios -R ${MONARCH_BASE}
	${CHOWN} root:nagios ${MONARCH_BASE}/bin/nagios_reload
	${CHMOD} 750 ${MONARCH_BASE}/bin/nagios_reload
	${CHMOD} u+s ${MONARCH_BASE}/bin/nagios_reload
	${CHOWN} root:nagios ${MONARCH_BASE}/bin/nmap_scan_one
	${CHMOD} 750 ${MONARCH_BASE}/bin/nmap_scan_one
	${CHMOD} u+s ${MONARCH_BASE}/bin/nmap_scan_one
	${MKDIR} -p ${CONFIG_BASE}
	${CP} -pn config/*.properties ${CONFIG_BASE}
	${CHOWN} nagios:nagios -R ${CONFIG_BASE}
	${SED} -i '/^Listen 80$$/s/80/8091/' ${APACHE2_PORTSCONF}
	${SED} -i '/^<VirtualHost \\*:80>$$/s/80/8091/' ${APACHE2_DEFAULTSITECONF}
	${CP} -p etc/monarch.conf ${APACHE2_SITES}
	${CP} -p etc/suexec-www-data ${APACHE2_SUEXEC}

install-nagios : all
	@if [ "`id -u`" -ne 0 -a "`id -un`" != nagios ]; then \
	    echo "ERROR:  You must be either root or nagios to install Monarch."; \
	    exit 1; \
	fi
	${MONARCH_BASE}/bin/install_nagios_files ${NAGIOS_BASE}/etc
	${RM} -rf ${NAGIOS_BASE}/etc/objects
	${RM} -f ${MONARCH_BASE}/bin/install_nagios_files
	${CP} -pn etc/send_nsca.cfg ${NAGIOS_BASE}/etc
	${CHOWN} nagios:nagios -R ${NAGIOS_BASE}/etc
	${CP} -p etc/nagios.conf ${APACHE2_SITES}

clean :
	${RM} -r ${TARGETDIR}
