# FhirPg

Postgresql/Relational persistance for FHIR models

## Description

Pure relational database for fhir resources

```

  {
    name: :patient
    attrs: {
      bith_date: { type: :date_time},
      active: { type: :boolean},
      gender: { type: :complex_type,
        attrs: {
          text: { type: :string},
          coding: { type: :string
            attrs: {
              system: { type: :string},
              code:   { type: :string},
            }
          },
        }
      }
    }
  }

  #SQL

  CREATE TABLE resources (
    resource_type fhir.resource_type, -- enum
    id uuid,

    -- inlined boolean,
    -- parent_id uuid
  )

  CREATE TABLE patients (

    bith_date timestamp,
    active boolean

  ) inherits (resources)

  CREATE TABLE patient_genders (
    id uuid primary key,
    patient_id uuid references patients(id),

    text varchar
  )

  CREATE TABLE patient_gender_codings (
    id uuid,
    patient_id uuid references patients(id),
    patient_gender_id uuid references patient_genders(id),

    system varchar,
    version varchar,
    code varchar,
    display varchar,
    primary boolean
  )

```

resource -> table
resource.attribute (enum || primitive) -> column
resource.attribute (complex type) -> table

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

```

on ubuntu 14.04 (trusty)
sudo apt-get install postgresql-9.3 postgresql-9.3-plv8 ...


## TODO

* resource references
* inline resources
* insert in postgresql
* array in json
* extensions

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
