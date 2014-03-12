# FHIRbase

Relational storage for [FHIR](http://hl7.org/implement/standards/fhir/) with document API

## Motivation

While crafting health IT systems you start understand value of right domain model.
FHIR is open source new generation lightweight standard for health data interop, which (we hope)
could be used as internal model for health IT systems. FHIR is based on concept of __resource__.


>> FHIR® is a next generation standards framework created by HL7.
>> FHIR combines the best features of HL7 Version 2,
>> Version 3 and CDA® product lines while leveraging the latest
>> web standards and applying a tight focus on implementability.
>> In terms of [Domain Driven Design]() __resource__ is an [aggregate](), which consist of __root entity__
>> (having identity) and set of aggregated __value objects__.

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

>> PostgreSQL is a powerful, open source object-relational database system.
>> It has more than 15 years of active development and a proven architecture
>> that has earned it a strong reputation for reliability, data integrity, and correctness.


## Schema generation

We use code generation based on FHIR machine readable specification to generate database schema and
CRUD procedures. All generation done in postgresql. We use advanced postgresql features

* xml
* json
* enum type
* arrays
* [inheritance](http://www.postgresql.org/docs/9.3/static/tutorial-inheritance.html)
* materialized views
* pgtap
* uuid extension
* plpython extension

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


* resource
  * id
  * _type
  * _unknown_attributes
  * resource_type
  * language
  * container_id
  * contained_id
  * created_at
* resource_component
  * id
  * _type
  * _unknown_attributes
  * parent_id
  * resource_id
  * container_id
  * created_at

## Usage

* insert, update & delete procedures
* aggregated resources views
* querying

## Demo

You can try upload resources and query storage using demo site - http://try-fhirbase.hospital-systems.com

## Installation

* requirements:
  * postgresql 9.3
  * postgresql-contrib
  * plpython
* create databae
* execute fhirbase.sql script

## Contribution

* Star us on github
* Create issue - for bug report or enhancment
* Contribute to FHIRbase (see dev/README.md to prepare development environment)

## Plans

* Extensions
* FHIR server implementation
* FHIR version migrations
* Oracle, MS SQL & Mysql support
