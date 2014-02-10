#!/usr/bin/env bash

#wget https://alioth.debian.org/scm/loggerhead/pkg-postgresql/postgresql-common/trunk/download/head:/apt.postgresql.org.s-20130224224205-px3qyst90b3xp8zj-1/apt.postgresql.org.sh
#chmod u+x apt.postgresql.org.sh

sudo /home/vagrant/fhirbase/apt.postgresql.org.sh

sudo apt-get install -y git build-essential libv8-dev libpq-dev postgresql-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3

test -d /tmp/plv8js || git clone https://code.google.com/p/plv8js/ /tmp/plv8js
cd /tmp/plv8js
sudo make
sudo make install

sudo su postgres -c 'createuser -s root'
sudo su postgres -c 'createuser -s vagrant'

sudo perl -MCPAN -e 'install TAP::Parser::SourceHandler::pgTAP'
test -d /tmp/pgtap || git clone https://github.com/theory/pgtap.git /tmp/pgtap
cd /tmp/pgtap
sudo make installcheck
sudo make install


grep 'plv8.start_proc' /etc/postgresql/9.3/main/postgresql.conf || sudo bash -c "echo 'plv8.start_proc = 'plv8_init'' >> /etc/postgresql/9.3/main/postgresql.conf"
grep 'max_locks_per_transaction = 200' /etc/postgresql/9.3/main/postgresql.conf || sudo bash -c "echo 'max_locks_per_transaction = 200' >> /etc/postgresql/9.3/main/postgresql.conf"
sudo service postgresql restart

cd /home/vagrant/fhirbase

./fbdev test
