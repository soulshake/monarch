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
	@echo "Primary install target:"
	@echo "(must be run as root or nagios)"
	@echo ""
	@echo "    make install"
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
	    echo "ERROR:  You must be either root or nagios to install the Monarch binaries."; \
	    exit 1; \
	fi

clean :
	${RM} ${TARGETDIR}
