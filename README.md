# FHIRbase

Relational storage for [FHIR](http://hl7.org/implement/standards/fhir/) with document API

## Motivation

While crafting health IT systems you start understand value of right domain model.
FHIR is open source new generation lightweight standard for health data interop, which (we hope)
could be used as internal model for health IT systems. FHIR is based on concept of __resource__.


> FHIR® is a next generation standards framework created by HL7.
> FHIR combines the best features of HL7 Version 2,
> Version 3 and CDA® product lines while leveraging the latest
> web standards and applying a tight focus on implementability.
> In terms of [Domain Driven Design]() __resource__ is an [aggregate](), which consist of __root entity__
> (having identity) and set of aggregated __value objects__.

There is concern - how to persist __resources__.

The simplest solution is just save them as text blobs in RDBMS or in distributed file storage system like (S3, Riak & Hadoop).
This solution simple and scalable, but has trade-offs:

* You should implement search and querying by creating hand-made indexes or using index engines like elastic search, solr etc
* query language will be very limited (in comparison with SQL)
* weak data consistency control - type checks, referential integrity, aggregate invariants
* complicated batch transformations

Second option is usage of document databases like MongoDb, CouchDb, RethinkDb etc. They feat better (removing some part
of hand work), but share some of trade-offs.

* Transaction consistency often works only on document level granularity, so you need manage complex transactions manually.
* Querying is less powerful and declarative then for relational databases (joins, aggregations)
* Document Databases sometimes are not yet really matured for enterprise (read mongo fails reports)

Third option - relational schema - solve most of this problems and bring new ones :)

* How to create such a complex schema?
* How to simplify aggregates (__resource__) operations (persistence, retrieval)?
* How to scale?

But we believe, that solving this problems we will get:

* Fine-Granularity of data control
* Rich Querying & Data Abstraction capabilities
* Enhanced Data Consistency - applying most of FHIR constraints on database level
* Storage Efficiency

Most of it required or desirable while programming Health IT systems.

## Why postgresq?

> PostgreSQL is a powerful, open source object-relational database system.
> It has more than 15 years of active development and a proven architecture
> that has earned it a strong reputation for reliability, data integrity, and correctness.

We actively use advanced postgresql features

* xml
* json
* enum type
* arrays
* [inheritance](http://www.postgresql.org/docs/9.3/static/tutorial-inheritance.html)
* materialized views
* pgtap
* uuid extension
* plpython extension ???

## Schema generation

We code-generate database schema & CRUD views & procedures from
FHIR machine readable specification (http://www.hl7.org/implement/standards/fhir/downloads.html).
All generation done in postgresql.

Generation steps:

* Convert FHIR meta specification from XML into more convenient relational form
* Generate schema using meta information
  * generate base tables - resource and resource_component
  * generate datatype's tables, inheriting from resource_component
  * generate enums for FHIR system enumerator types
  * generate tables for each resource
     * root entity table inherits from resource base table
     * components & complex type tables inhrits from resource base table
* Generate views & procedures for CRUD
  * generate views, which return resource as json aggregate
  * generate insert_resource(resource json) - put resource data in
  * create delete procedure
  * create update procedure as delete & insert
* Run tests
* Dump resulting database as end-user sql script

## Schema Overview

We heavily use postgresql inheritance for schema infrastructure.

There are two base tables:

* resource - base table for all __root entities__ of resources
* resource_component - base table for all __value objects__ (resource components)

Each resource represented as __root entity__ table (for example 'patient')
and table per component (for exampl: patient.contact is saved in `patient_contact` table).

This point is illustrated on picture bellow:

![schema1](doc/schema1.png)

[edit](http://yuml.me/edit/1f3c8e92)

Due to inheritance we can access all resources throughout  __resource__ table
and all resource components in __resource_component__.


### Description of resource table

Base table for all resource aggregate root tables

```sql
  CREATE TABLE resource (
      id uuid NOT NULL, -- surrogate resource id
      _type varchar , -- real table name (i.e. where data are saved)
      _unknown_attributes json, -- json where all unknown attributes will be saved
      resource_type character varying, -- resourceType see FHIR documentation
      language character varying, -- see FHIR documentation
      container_id uuid, -- not null and references aggregating resource if resource is contained
      contained_id character varying, -- original contained id from resource aggregate
      created_at timestamp without time zone DEFAULT now() -- timestamp field
  );
```

### Description resource_component table

Base table for all resource components

```sql
  CREATE TABLE resource_component (
      id uuid NOT NULL, -- surrogate component id
      _type character varying NOT NULL, -- real table name
      _unknown_attributes json, -- json where all unknown attributes will be saved
      parent_id uuid NOT NULL, -- reference to parent component if present
      resource_id uuid NOT NULL -- denormalized reference to resource root table, see explanations below
  );
```

### Primitive datatype attributes

Here is mapping table for primitive types from FHIR to postgresql:

```sql

  CREATE TABLE type_to_pg_type (
      type character varying,
      pg_type character varying
  );

  COPY type_to_pg_type (type, pg_type) FROM stdin;
  code         	varchar
  date_time         	timestamp
  string         	varchar
  text         	text
  uri                  	varchar
  datetime         	timestamp
  instant      	timestamp
  boolean       	boolean
  base64_binary	bytea
  integer         	integer
  decimal         	decimal
  sampled_data_data_type	text
  date         	date
  id                  	varchar
  oid	               varchar
  \.

```

### Enumerations

For FHIR system enumerated types we create postgresql ENUMs:

```sql
  CREATE TYPE "AddressUse" AS ENUM (
      'home',
      'work',
      'temp',
      'old'
  );

```

### Complex datatype attributes

We create table for each compound datatype,
inheriting from resource_component table.

Here is how table for address type created:

```sql

  CREATE TABLE address (
      use "AddressUse",
      text character varying,
      line character varying[],
      city character varying,
      state character varying,
      zip character varying,
      country character varying
  )
  INHERITS (resource_component);

```

For resource attributes with such compound type we create separate
tables (for the sake of separation of storage and consistency) and
inherits it from type base table:

```sql

  CREATE TABLE organization_address ()
  INHERITS (address);

```

### Tables abbreviations

Postgresql with default configuration limit length of table names.
So we don't want require postgresql rebuild and shortening table names
using following abbreviation table:


```sql

CREATE TABLE short_names (name varchar, alias varchar);
INSERT INTO short_names (name, alias)
VALUES
    ('capabilities', 'cap'),
    ('chanel', 'chnl'),
    ('codeable_concept', 'cc'),
    ('coding', 'cd'),
    ('identifier', 'idn'),
    ('immunization', 'imm'),
    ('immunization_recommendation', 'imm_rec'),
    ('location', 'loc'),
    ('medication', 'med'),
    ('medication_administration', 'med_adm'),
    ('medication_dispense', 'med_disp'),
    ('medication_prescription', 'med_prs'),
    ('medication_statement', 'med_st'),
    ('observation', 'obs'),
    ('prescription', 'prs'),
    ('recommentdaton', 'rcm'),
    ('resource_reference', 'res_ref'),
    ('value', 'val'),
    ('value_set', 'vs')
;

```

### Contained Resources

FHIR allows on level resource - resource aggregation,
see http://www.hl7.org/implement/standards/fhir/references.html.

We save __contained resources___ same way as resources, but saving
in __container_id__ reference to parent resource, and preserving symbolic local resource id
in __contained_id__ field.

### Resource References

Now resource references saved as other compound types, but we
are looking for more relational solution for referential integrity
and reference traversing.

### Extensions

TODO: working on solution

### Views

### insert_resource(resource json)

### delete_resource(id uuid)

### update_resource(resource json)

## Demo

Here are interactive demo - http://try-fhirbase.hospital-systems.com,
where you can upload and query fhirbase.

## Installation

* requirements:
  * postgresql 9.3
  * postgresql-contrib
  * plpython
* create databae
* execute fhirbase.sql script

## Usage

* insert, update & delete procedures
* aggregated resources views
* querying

## Contribution

* Star us on github
* Create issue - for bug report or enhancment
* Contribute to FHIRbase (see dev/README.md to prepare development environment)

## Plans

* Extensions
* FHIR server implementation
* FHIR version migrations
* Oracle, MS SQL & Mysql support
