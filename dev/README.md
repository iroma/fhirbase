# FHIRBase

Document/Relational hybryde database for FHIR

## Requirements

* postgresql 9.3
* postgresql-contrib
* plv8

## Installation

* checkout project
* cd dev/
* bundle install
* configure generation/connection.yml
* rspec generation_spec/

## Structure

* generation - ruby for schema generation
* js_src - coffe for postgresql js function


## Installation

* checkout project
* bundle install
* configure spec/connection.yml
* rspec spec

Install plv8 on ubuntu 13.04
apt-source deb http://apt.postgresql.org/pub/repos/apt/ squeeze-pgdg main

```bash
git clone https://code.google.com/p/plv8js/
cd plv8js

sudo apt-get install libv8 libv8-dev libpq
sudo apt-get install postgresql-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3
sudo apt-get install libpq-dev
sudo make
sudo make install

ubuntu 13.10

sudo add-apt-repository ppa:chris-lea/postgresql-9.3
sudo apt-get install postgresql-server-dev-9.3
sudo apt-get install postgresql-contrib-9.3

git clone https://code.google.com/p/plv8js/
cd plv8js
make
sudo make install


```

on ubuntu 14.04 (trusty)
sudo apt-get install postgresql-9.3 postgresql-9.3-plv8 ...

sudo vim /etc/postgresql/9.3/main/postgresql.conf
plv8.start_proc = 'plv8_init'


Install nodejs (nvm)

npm install -g coffee-script
npm install js2coffee
coffee --compile --output db/src/ db/js/

