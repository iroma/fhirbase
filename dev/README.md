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


## Architecture

There are two base tables:

table resource (
  id uuid PRIMARY KEY,
  resource_type varchar not null,
  container_id uuid references #{schema}.resource (id)
)

table resource_component
 id uuid PRIMARY KEY,
 parent_id uuid references resource_component (id),
 resource_id uuid references resource (id),
 compontent_type varchar,
 container_id uuid references #{schema}.resource (id) -- denormalization ?
)

table resource_datatype
 id uuid PRIMARY KEY,
 parent_id uuid references resource_component (id),
 resource_id uuid references resource (id),
 compontent_type varchar,
 container_id uuid references #{schema}.resource (id) -- denormalization ?
)

All other tables inherit from resource or resource_component
We store fhir data using two layers
1. two base tables for storing resource structure (relations between resource parts)
2. all other inherited tables store only data columns
3. for all complex types we generate base tables inherited from resource_datatypes
so we can extend primary datatypes

## Enums


## DataTypes

### Resource  implement in base table for resources)
@excluded

implemented as base table for resources

* language          code
* text              Narrative => pg/xml
* text_status       enum(NarrativeStatus)
* contained         Resource.Inline

### Narrative

@excluded (inlined into resource)

* status  enum(NarrativeStatus)  => pg/enum
* xhtml:div  => pg/xml

### Period => pg/range of dates

@compound

can be implemented as range of dates

* start     dateTime
* end       dateTime

### Coding

@compound

related to dictionaries (code system conversions etc)

* system         uri
* version        string
* code           code
* display        string
* primary        boolean
* valueSet       ResourceReference

### Quantity

@compound

Units stuff: systems & conversions (UCUM)

* value             | decimal
* comparator        | QuantityCompararator
* units             | string
* system            | uri
* code              | code

### Range

@compound (excesive tables, but 1-1 relation)

It would be cool to have range arythmetic for simple ranges

Postgres range arythmetic, but Quantity

* low               | Quantity
* high              | Quantity

### Ratio

@compound (excesive tables, but 1-1 relation)

arythmetic?

* numerator         | Quantity
* denominator       | Quantity


### Attachment

@compound (blobs!)

Big blob problem; automatic hash calculation (ideas: s3 FDW)

* contentType       | code
* language          | code
* data              | base64Binary
* url               | uri
* size              | integer
* hash              | base64Binary
* title             | string


### SampledData

format for time series

@compound (ups 2 level and 1-1)

* origin            | Quantity
* period            | decimal
* factor            | decimal
* lowerLimit        | decimal
* upperLimit        | decimal
* dimensions        | integer
* data              | SampledDataDataType


### ResourceReference

@exclude ?

Traverse through resources, foreighn key check

reference         | string
display           | string

### CodeableConcept

@compound (2 levels and 1-*)

See codings

* coding            | Coding
* text              | string

### Identifier

@compound

link to resource, breack bounds of datatypes

* use               | IdentifierUse
* label             | string
* system            | uri
* value             | string
* period            | Period
* assigner          | ResourceReference

### Schedule

@compound (2 level and 1-*)

schedule arythmetic

* Schedule          | event             | Period               |          0 | unbounded
* Schedule          | repeat            | Schedule.Repeat      |          0 | 1
* Schedule.Repeat   | frequency         | integer              |          0 | 1
* Schedule.Repeat   | when              | EventTiming          |          0 | 1
* Schedule.Repeat   | duration          | decimal              |          1 | 1
* Schedule.Repeat   | units             | UnitsOfTime          |          1 | 1
* Schedule.Repeat   | count             | integer              |          0 | 1
* Schedule.Repeat   | end               | dateTime             |          0 | 1


### Contact

@compound (2 level and 1-1)

search, simple compound type

* system            | ContactSystem        |          0 | 1          | Telecommunications form for contact - what communications system is required to make use of the contact.
* value             | string               |          0 | 1          | The actual contact details, in a form that is meaningful to the designated communication system (i.e. phone number or email address).
* use               | ContactUse           |          0 | 1          | Identifies the context for the address.
* period            | Period               |          0 | 1          | Time period when the contact was/is in use.

### Address

@compound (2 level and 1-1)

search, simple compound type

* use               | AddressUse           |          0 | 1          | Identifies the intended purpose of this address.
* text              | string               |          0 | 1          | A full text representation of the address.
* line              | string               |          0 | unbounded  | This component contains the house number, apartment number, street name, street direction,                                                                                                                                                                                                                                                                                                                                                                               +
* city              | string               |          0 | 1          | The name of the city, town, village or other community or delivery center.
* state             | string               |          0 | 1          | Sub-unit of a country with limited sovereignty in a federally organized country. A code may be used if codes are in common use (i.e. US 2 letter state codes).
* zip               | string               |          0 | 1          | A postal code designating a region defined by the postal service.
* country           | string               |          0 | 1          | Country. ISO 3166 3 letter codes can be used in place of a full country name.
* period            | Period               |          0 | 1          | Time period when address was/is in use.

### HumanName

@compound (2 level and 1-1)

search, simple compound type

* use               | NameUse              |          0 | 1          | Identifies the purpose for this name.
* text              | string               |          0 | 1          | A full text representation of the name.
* family            | string               |          0 | unbounded  | Family name, this is the name that links to the genealogy. In some cultures (e.g. Eritrea) the family name of a son is the first name of his father.
* given             | string               |          0 | unbounded  | Given name. NOTE: Not to be called "first name" since given names do not always come first.
* prefix            | string               |          0 | unbounded  | Part of the name that is acquired as a title due to academic, legal, employment or nobility status, etc. and that comes at the start of the name.
* suffix            | string               |          0 | unbounded  | Part of the name that is acquired as a title due to academic, legal, employment or nobility status, etc. and that comes at the end of the name.
* period            | Period               |          0 | 1          | Indicates the period of time when this name was valid for the named person.

Cases:

@excluded

(cases attr2datatype 1-1)
  @compound
  @compound (2 level & 1-1)
  @compound (2 level & 1-*)

* custom types
* hstore || json
* tables

## Project Structure

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


## install pgTap (xUnit for SQL)

```bash
  cd tmp
  git clone git@github.com:theory/pgtap.git
  cd pgtap

  make
  make installcheck
  sudo make install
```
