# monarch
Monarch

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
apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
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
service nagios start

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
cd /tmp
rm -rf debian-perl-packages-master
rm -rf master.zip
rm -rf monarch-GROUNDWORK
rm -rf GROUNDWORK.zip
a2enmod cgi
a2enmod suexec
service apache2 start

# feeders
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
service supervisor start
sleep 5
supervisorctl status all
service nagios restart
````
