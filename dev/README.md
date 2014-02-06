# FHIRBase

Document/Relational hybryde database for FHIR

## Requirements

* postgresql 9.3
* postgresql-contrib
* plv8
* pgtap (for development)
* npm && node && coffeescript (for development)

## Installation

* checkout project
* cd dev/
* bundle install
* configure generation/connection.yml
* rspec generation_spec/

## Project Layout

* development environment
  * requirements (see requirements)
  * database structure (dev/install.sql)
  * tests (dev/test.sql)

* end user build
  * build script (fhirbase.sql)
  * documentation (plv8 installation & postgresql configuration)

## Development

* javascript (cofee) for functions (insert_resource, utilities, schema generation)
* classic postgresql views for manipulating fhir structure data

## Build

1. create meta schema (datatype & resource desc tables)
1. load data from xml:  fhir-base.xsd (datatypes) & profiles-resources.xml (resource descriptinos)
1. generate views (comprehensive for schema generation)
1. generate datatypes & resources schema
1. generate view & insert
1. generate sql for end-user build

## Meta schema description

There are two base tables:

* meta.datatypes -
* meta.datatype_elements -
* meta.datatype_enums -
* meta.resource_elements -
* meta.type_to_pg_type -

## Schema

### Base tables

table resource - base table for all resource tables
table resource_component - base table for all nested into resource value objects & base table for all complex datatypes tables

## Installation instructions

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


install pgTap (xUnit for SQL)

```bash
  cd tmp
  git clone git@github.com:theory/pgtap.git
  cd pgtap

  make
  make installcheck
  sudo make install
```
