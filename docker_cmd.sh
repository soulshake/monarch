#!/bin/bash

cd /src
make install-nagios

# todo: put these in /docker-entrypoint-initdb.d/
cd /tmp/monarch-GROUNDWORK
sleep 5
PGPASSWORD=postgres psql -h localhost -U postgres -d postgres -f etc/01-create-fresh-monarch.sql
PGPASSWORD=gwrk psql -h localhost -U monarch -d monarch -f etc/02-monarch-db.sql
PGPASSWORD=gwrk psql -h localhost -U monarch -d monarch -f etc/03-monarch-seed.sql

service --status-all
service nagios start
service apache2 start
service supervisor start

ln -s /usr/local/groundwork/nagiosfeeders/var/* /var/log/

sed -i 's/host.docker.internal/localhost/' /usr/local/groundwork/config/*
sed -i 's/host.docker.internal/localhost/' /src/config/*
sed -i 's/80/8091/' /etc/apache2/ports.conf

sleep 999999
