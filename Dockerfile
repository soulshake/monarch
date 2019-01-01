FROM ubuntu:bionic

# headless nagios
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apache2 \
        autoconf \
        gcc \
        libapache2-mod-php7.2 \
        libc6 \
        libgd-dev \
        make \
        php \
        unzip \
        wget
# RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \

WORKDIR /tmp
RUN wget https://github.com/rwatler/nagioscore/archive/GROUNDWORK.zip \
    && unzip GROUNDWORK.zip \
    && rm -rf GROUNDWORK.zip
WORKDIR /tmp/nagioscore-GROUNDWORK
ENV CFLAGS='-pthread -DUSE_CHECK_RESULT_DOUBLE_LINKED_LIST -O2'
RUN ./configure --enable-event-broker
RUN useradd nagios
RUN make all \
    && make install \
    && make install-init \
    && make install-config \
    && make install-commandmode \
    && make install-headers

# Bronx
RUN apt-get install -y \
    libapr1-dev \
    libaprutil1-dev \
    libmcrypt-dev \
    libwrap0-dev \
    libdb5.3-dev
WORKDIR /tmp
RUN wget https://github.com/rwatler/bronx/archive/GROUNDWORK.zip \
    && unzip GROUNDWORK.zip \
    && rm -rf GROUNDWORK.zip
WORKDIR /tmp/bronx-GROUNDWORK
RUN make all && make install

# nagios plugins
RUN apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
RUN apt-get install -y dnsutils openssh-client libmysqlclient-dev libpq-dev

WORKDIR /tmp
RUN wget -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.2.1.tar.gz \
    && tar zxf nagios-plugins.tar.gz \
    && rm -rf /tmp/nagios-plugins.tar.gz
WORKDIR /tmp/nagios-plugins-release-2.2.1/
RUN ./tools/setup \
    && ./configure \
    && make \
    && make install \
    && rm -rf /tmp/nagios-plugins-release-2.2.1


# nagios nrpe plugin
WORKDIR /tmp
RUN wget https://github.com/NagiosEnterprises/nrpe/archive/nrpe-2-15.zip \
    && unzip nrpe-2-15.zip \
    && rm -rf nrpe-2-15.zip
WORKDIR /tmp/nrpe-nrpe-2-15
RUN ./configure --with-ssl-lib=/usr/lib/x86_64-linux-gnu \
    && make all
RUN cp -p src/check_nrpe /usr/local/nagios/libexec
RUN cp -p src/nrpe /usr/local/bin
RUN rm -rf /tmp/nrpe-nrpe-2-15
#+cd /tmp
#+rm -rf nrpe-2-15.zip
#+rm -rf 
#+
# custom/extended nagios plugins
RUN apt-get install -y autoconf gcc libdatetime-perl make build-essential g++ python-dev
RUN apt-get install -y libconfig-inifiles-perl libnumber-format-perl
WORKDIR /tmp
RUN wget https://github.com/rwatler/nagios-plugins/archive/GROUNDWORK.zip \
    && unzip GROUNDWORK.zip \
    && rm -rf GROUNDWORK.zip
WORKDIR /tmp/nagios-plugins-GROUNDWORK
RUN cp -pr libexec/* /usr/local/nagios/libexec
WORKDIR /tmp/nagios-plugins-GROUNDWORK/src
RUN ls -lahF
RUN unzip wmic-1.3.14.zip
WORKDIR wmic-master
ENV ZENHOME=/tmp/nagios-plugins-GROUNDWORK
RUN mkdir -p Samba/source/bin/static
RUN make "CPP=gcc -E -ffreestanding"
RUN cp -p /tmp/nagios-plugins-GROUNDWORK/bin/winexe /usr/local/bin
RUN cp -p /tmp/nagios-plugins-GROUNDWORK/bin/wmic /usr/local/bin
RUN rm -rf /tmp/nagios-plugins-GROUNDWORK

# feeders
RUN apt-get install -y \
    supervisor \
    libdatetime-perl \
    libdatetime-format-strptime-perl \
    libdatetime-format-builder-perl
WORKDIR /tmp
RUN wget https://github.com/rwatler/nagios-feeders/archive/GROUNDWORK.zip \
    && unzip GROUNDWORK.zip \
    && rm -rf GROUNDWORK.zip
WORKDIR /tmp/nagios-feeders-GROUNDWORK
RUN make all \
    && make install \
    && rm -rf /tmp/nagios-feeders-GROUNDWORK

# monarch
RUN apt-get install -y \
    postgresql-client \
    snmp \
    sendemail \
    nsca-client \
    apache2-suexec-custom \
    libcgi-pm-perl \
    libcgi-session-perl \
    libclass-std-utils-perl \
    libmoose-perl \
    librrds-perl \
    libxml-libxml-perl \
    liblog-log4perl-perl
WORKDIR /tmp
RUN wget https://github.com/rwatler/debian-perl-packages/archive/master.zip \
    && unzip master.zip \
    && rm -rf master.zip
RUN apt-get install -y \
    ./debian-perl-packages-master/libcgi-ajax-perl/libcgi-ajax-perl_0.707+gw-1_all.deb \
    ./debian-perl-packages-master/libclass-generate-perl/libclass-generate-perl_1.17-1_all.deb \
    ./debian-perl-packages-master/libnmap-scanner-perl/libnmap-scanner-perl_1.0+gw-1_all.deb \
    ./debian-perl-packages-master/libhtml-tooltip-javascript-perl/libhtml-tooltip-javascript-perl_1.01-1_all.deb \
    ./debian-perl-packages-master/libjavascript-dataformvalidator-perl/libjavascript-dataformvalidator-perl_0.50-1_all.deb \
    ./debian-perl-packages-master/libtypedconfig-perl/libtypedconfig-perl_1.3.1-1_all.deb \
    ./debian-perl-packages-master/libcollagequery-perl/libcollagequery-perl_0.8.3-1_all.deb \
    ./debian-perl-packages-master/libgw-rapid-perl/libgw-rapid-perl_0.9.8-1_all.deb \
    ./debian-perl-packages-master/libmonarchfoundationrest-perl/libmonarchfoundationrest-perl_8.0.0-1_all.deb \
    ./debian-perl-packages-master/libmonarchlocks-perl/libmonarchlocks-perl_8.0.0-1_all.deb


COPY . /src
# WORKDIR /src
#RUN wget https://github.com/rwatler/monarch/archive/GROUNDWORK.zip -O /src/GROUNDWORK.zip \
    #&& unzip GROUNDWORK.zip \
    #&& rm -rf GROUNDWORK.zip

#WORKDIR /src/monarch-GROUNDWORK
WORKDIR /src/
RUN make all \
    && make install \
    && rm -rf \
        /src/debian-perl-packages-master \
        /src/monarch-GROUNDWORK

RUN a2enmod cgi \
    && a2enmod suexec

RUN apt install -y curl
RUN apt install -y vim
#COPY . /src
#WORKDIR /src
CMD /src/docker_cmd.sh


