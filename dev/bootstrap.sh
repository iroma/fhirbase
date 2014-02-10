#!/usr/bin/env bash

#wget https://alioth.debian.org/scm/loggerhead/pkg-postgresql/postgresql-common/trunk/download/head:/apt.postgresql.org.s-20130224224205-px3qyst90b3xp8zj-1/apt.postgresql.org.sh
#chmod u+x apt.postgresql.org.sh

whoami

if [ ! -d /etc/postgresql/9.3 ]; then
  sudo /home/vagrant/fhirbase/apt.postgresql.org.sh
fi

sudo apt-get install -y curl git build-essential libv8-dev libpq-dev postgresql-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3

if [ ! -d /tmp/plv8js ]; then
  git clone https://code.google.com/p/plv8js/ /tmp/plv8js
  cd /tmp/plv8js
  sudo make
  sudo make install
  sudo service postgresql restart
fi

if [ ! `which coffee`]; then
  sudo su -l vagrant -c 'curl https://raw.github.com/creationix/nvm/master/install.sh | sh'
  sudo su -l vagrant -c 'nvm install 0.10'
  sudo su -l vagrant -c 'nvm alias default 0.10'
  sudo su -l vagrant -c 'node -v'
  sudo su -l vagrant -c 'npm install -g coffee-script'
fi

exit

sudo su postgres -c 'createuser -s root'
sudo su postgres -c 'createuser -s vagrant'



if [ ! -d /tmp/pgtap ]; then
  sudo perl -MCPAN -e 'install TAP::Parser::SourceHandler::pgTAP'
  git clone https://github.com/theory/pgtap.git /tmp/pgtap
  cd /tmp/pgtap
  sudo make installcheck
  sudo make install
  sudo service postgresql restart
  psql -d postgres -c 'CREATE EXTENSION pgtap;'
fi

if [ `grep -v 'plv8.start_proc' /etc/postgresql/9.3/main/postgresql.conf` ]; then
  sudo bash -c "echo 'plv8.start_proc = 'plv8_init'' >> /etc/postgresql/9.3/main/postgresql.conf"
  sudo bash -c "echo 'max_locks_per_transaction = 200' >> /etc/postgresql/9.3/main/postgresql.conf"
  sudo service postgresql restart
fi

cd /home/vagrant/fhirbase

./fbdev test
