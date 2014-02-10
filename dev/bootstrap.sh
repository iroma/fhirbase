#!/usr/bin/env bash

#wget https://alioth.debian.org/scm/loggerhead/pkg-postgresql/postgresql-common/trunk/download/head:/apt.postgresql.org.s-20130224224205-px3qyst90b3xp8zj-1/apt.postgresql.org.sh
#chmod u+x apt.postgresql.org.sh

whoami

if [ ! -d /etc/postgresql/9.3 ]; then
  sudo /home/vagrant/fhirbase/apt.postgresql.org.sh
fi

sudo apt-get install -y curl git libpq-dev postgresql-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3 postgresql-plpython-9.3

sudo su postgres -c 'createuser -s root'
sudo su postgres -c 'createuser -s vagrant'

grep -v 'max_locks_per_transaction = 200' /etc/postgresql/9.3/main/postgresql.conf && (sudo bash -c "echo 'max_locks_per_transaction = 200' >> /etc/postgresql/9.3/main/postgresql.conf" && sudo service postgresql restart)

if [ ! -d /tmp/pgtap ]; then
  git clone https://github.com/theory/pgtap.git /tmp/pgtap
  cd /tmp/pgtap
  make
  sudo make install
  sudo make installcheck
  sudo service postgresql restart
  psql -d postgres -c 'CREATE EXTENSION pgtap;'
  echo y | sudo perl -MCPAN -e 'install TAP::Parser::SourceHandler::pgTAP'
fi


sudo su -l vagrant -c 'cd /home/vagrant/fhirbase  && ./fbdev test'
