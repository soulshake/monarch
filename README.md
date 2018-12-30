# monarch

Monarch: [http://localhost:8091/monarch/cgi-bin/monarch.cgi](http://localhost:8091/monarch/cgi-bin/monarch.cgi)

* Hosts: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=hosts](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=hosts)
* Services: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=services](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=services)
* Profiles: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=profiles](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=profiles)
* Commands: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=commands](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=commands)
* Time Periods: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?time_periods=hosts](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=time_periods)
* Contacts: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=contacts](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=contacts)
* Escalations: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=escalations](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=escalations)
* Groups: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=groups](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=groups)
* Control: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=control](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=control)
* Tools: [http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=tools](http://localhost:8091/monarch/cgi-bin/monarch.cgi?top_menu=tools)

Status log: [http://localhost:8091/nagios/var/status.log](http://localhost:8091/nagios/var/status.log)

Ubuntu Build Instructions, (currently assumes Postgres and Groundwork running on Docker host):

````
# docker
docker pull ubuntu:bionic
docker run -it -p 8091:80 -p 5667:5667 -p 5677:5677 --add-host host.docker.internal:172.17.0.1 --name monarch ubuntu:bionic bash

# headless nagios
apt-get update
apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php7.2 libgd-dev
    note: tzdata: 12 - US, 10 - Pacific
cd /tmp
wget https://github.com/rwatler/nagioscore/archive/GROUNDWORK.zip
unzip GROUNDWORK.zip
cd nagioscore-GROUNDWORK
CFLAGS='-pthread -DUSE_CHECK_RESULT_DOUBLE_LINKED_LIST -O2' ./configure --enable-event-broker
useradd nagios
make all
make install
make install-init
make install-config
make install-commandmode
make install-headers
cd /tmp
rm -rf nagioscore-GROUNDWORK
rm -rf GROUNDWORK.zip

# bronx
apt-get install -y libapr1-dev libaprutil1-dev libmcrypt-dev libwrap0-dev libdb5.3-dev
cd /tmp
wget https://github.com/rwatler/bronx/archive/GROUNDWORK.zip
unzip GROUNDWORK.zip
cd bronx-GROUNDWORK
make all
make install
cd /tmp
rm -rf bronx-GROUNDWORK
rm -rf GROUNDWORK.zip

# nagios plugins
apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext dnsutils openssh-client libmysqlclient-dev
cd /tmp
wget -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.2.1.tar.gz
tar zxf nagios-plugins.tar.gz
cd /tmp/nagios-plugins-release-2.2.1/
./tools/setup
./configure
make
make install
cd /tmp
rm -rf nagios-plugins-release-2.2.1
rm -rf nagios-plugins.tar.gz

# nagios nrpe plugin
cd /tmp
wget https://github.com/NagiosEnterprises/nrpe/archive/nrpe-2-15.zip
unzip nrpe-2-15.zip
cd nrpe-nrpe-2-15
./configure --with-ssl-lib=/usr/lib/x86_64-linux-gnu
make all
cp -p src/check_nrpe /usr/local/nagios/libexec
cp -p src/nrpe /usr/local/bin
cd /tmp
rm -rf nrpe-2-15.zip
rm -rf nrpe-nrpe-2-15

# custom/extended nagios plugins
apt-get install -y autoconf gcc libdatetime-perl make build-essential g++ python-dev
apt-get install -y libconfig-inifiles-perl libnumber-format-perl
cd /tmp
wget https://github.com/rwatler/nagios-plugins/archive/GROUNDWORK.zip
unzip GROUNDWORK.zip
cd nagios-plugins-GROUNDWORK
cp -pr libexec/* /usr/local/nagios/libexec
cd src
unzip wmic-1.3.14.zip
cd wmic-master
export ZENHOME=/tmp/nagios-plugins-GROUNDWORK
mkdir -p Samba/source/bin/static
make "CPP=gcc -E -ffreestanding"
cp -p /tmp/nagios-plugins-GROUNDWORK/bin/winexe /usr/local/bin
cp -p /tmp/nagios-plugins-GROUNDWORK/bin/wmic /usr/local/bin
cd /tmp
rm -rf GROUNDWORK.zip
rm -rf nagios-plugins-GROUNDWORK

# nagios feeders
apt-get install -y supervisor
apt-get install -y libdatetime-perl libdatetime-format-strptime-perl libdatetime-format-builder-perl
cd /tmp
wget https://github.com/rwatler/nagios-feeders/archive/GROUNDWORK.zip
unzip GROUNDWORK.zip
cd nagios-feeders-GROUNDWORK
make all
make install
cd /tmp
rm -rf nagios-feeders-GROUNDWORK
rm -rf GROUNDWORK.zip

# monarch
apt-get install -y postgresql-client snmp sendemail nsca-client apache2-suexec-custom
apt-get install -y libcgi-pm-perl libcgi-session-perl libclass-std-utils-perl libmoose-perl librrds-perl libxml-libxml-perl liblog-log4perl-perl
cd /tmp
wget https://github.com/rwatler/debian-perl-packages/archive/master.zip
unzip master.zip
apt-get install -y ./debian-perl-packages-master/libcgi-ajax-perl/libcgi-ajax-perl_0.707+gw-1_all.deb
apt-get install -y ./debian-perl-packages-master/libclass-generate-perl/libclass-generate-perl_1.17-1_all.deb
apt-get install -y ./debian-perl-packages-master/libnmap-scanner-perl/libnmap-scanner-perl_1.0+gw-1_all.deb
apt-get install -y ./debian-perl-packages-master/libhtml-tooltip-javascript-perl/libhtml-tooltip-javascript-perl_1.01-1_all.deb
apt-get install -y ./debian-perl-packages-master/libjavascript-dataformvalidator-perl/libjavascript-dataformvalidator-perl_0.50-1_all.deb
apt-get install -y ./debian-perl-packages-master/libtypedconfig-perl/libtypedconfig-perl_1.3.1-1_all.deb
apt-get install -y ./debian-perl-packages-master/libcollagequery-perl/libcollagequery-perl_0.8.3-1_all.deb
apt-get install -y ./debian-perl-packages-master/libgw-rapid-perl/libgw-rapid-perl_0.9.8-1_all.deb
apt-get install -y ./debian-perl-packages-master/libmonarchfoundationrest-perl/libmonarchfoundationrest-perl_8.0.0-1_all.deb
apt-get install -y ./debian-perl-packages-master/libmonarchlocks-perl/libmonarchlocks-perl_8.0.0-1_all.deb
cd /tmp
wget https://github.com/rwatler/monarch/archive/GROUNDWORK.zip
unzip GROUNDWORK.zip
cd monarch-GROUNDWORK
make all
make install
PGPASSWORD=postgres psql -h host.docker.internal -U postgres -d postgres -f etc/01-create-fresh-monarch.sql
PGPASSWORD=gwrk psql -h host.docker.internal -U monarch -d monarch -f etc/02-monarch-db.sql
PGPASSWORD=gwrk psql -h host.docker.internal -U monarch -d monarch -f etc/03-monarch-seed.sql
sed -i 's/localhost/host.docker.internal/g' /usr/local/groundwork/config/db.properties
sed -i 's/localhost/host.docker.internal/g' /usr/local/groundwork/config/ws_client.properties
make install-nagios
cd /tmp
rm -rf debian-perl-packages-master
rm -rf master.zip
rm -rf monarch-GROUNDWORK
rm -rf GROUNDWORK.zip
a2enmod cgi
a2enmod suexec

# start
service apache2 start
service nagios start
service supervisor start
sleep 5
supervisorctl status all
````

Postgres access from container:

- pg_hba.conf:

  ````
  # IPv4 connections:
  host    all             all             0.0.0.0/0               md5

  ````

- postgresql.conf:
  ````
  listen_addresses = '*'
  ````

Groundwork access from container:

````
SERVER_ADDRESS=0.0.0.0 java -DGROUNDWORK_CONFIG=src/main/config -DGROUNDWORK_OUTPUT=/tmp -Djava.net.preferIPv4Stack=true -jar target/gw-server-8.0.0-SNAPSHOT.jar
````
