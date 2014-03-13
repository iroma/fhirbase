# FHIRBase Developers Guide

## Requirements

* postgresql 9.3
* postgresql-contrib
* pgtap

## Installation

### Vagrant box

### Ubuntu

You can setup vagrant virtual machine in minutes.

* checkout project
* cd dev/
* ./bootstrap.sh
* cp cfg/config.sh.template config.sh
* # edit cfg/config.sh and change configuration
* ./runme -h


```bash

sudo apt-get install libpq
sudo apt-get install postgresql-9.3 postgresql-contrib-9.3 postgresql-server-dev-9.3
sudo apt-get install libpq-dev

ubuntu 13.10

sudo add-apt-repository ppa:chris-lea/postgresql-9.3
sudo apt-get install postgresql-server-dev-9.3
sudo apt-get install postgresql-contrib-9.3

```

on ubuntu 14.04 (trusty)
sudo apt-get install postgresql-9.3

sudo vim /etc/postgresql/9.3/main/postgresql.conf


install pgTap (xUnit for SQL)

```bash
  cd tmp
  git clone git@github.com:theory/pgtap.git
  cd pgtap

  make
  make installcheck
  sudo make install
```
