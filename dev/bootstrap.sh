#!/usr/bin/env bash

sudo apt-get install -y git build-essential

wget https://alioth.debian.org/scm/loggerhead/pkg-postgresql/postgresql-common/trunk/download/head:/apt.postgresql.org.s-20130224224205-px3qyst90b3xp8zj-1/apt.postgresql.org.sh
chmod u+x apt.postgresql.org.sh
sudo ./apt.postgresql.org.sh

sudo apt-get install -y postgresql-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3
sudo apt-get install -y libv8-dev libpq-dev

test -d plv8js || git clone https://code.google.com/p/plv8js/
cd plv8js
make
sudo make install

cd

sudo su postgres -c createuser -s root

sudo perl -MCPAN -e 'install TAP::Parser::SourceHandler::pgTAP'
test -d pgtap || git clone https://github.com/theory/pgtap.git
cd pgtap
sudo make installcheck
sudo make install
