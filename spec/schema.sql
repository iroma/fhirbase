drop schema if exists fhir cascade;
create schema fhir;
CREATE TYPE "fhir".resource_type AS ENUM ('Patient','Organization','Practitioner','Encounter');
CREATE TABLE "fhir".resources (
"resource_type" fhir.resource_type,
"id" uuid,
"inline_id" varchar,
"container_id" uuid,
 PRIMARY KEY(id)) ;
CREATE TYPE "fhir".narrative_status AS ENUM ('additional','empty','extensions','generated');
CREATE TYPE "fhir".quantity_compararator AS ENUM ('<','<=','>','>=');
CREATE TYPE "fhir".identifier_use AS ENUM ('official','secondary','temp','usual');
CREATE TYPE "fhir".event_timing AS ENUM ('AC','ACD','ACM','ACV','HS','PC','PCD','PCM','PCV','WAKE');
CREATE TYPE "fhir".units_of_time AS ENUM ('a','d','h','min','mo','s','wk');
CREATE TYPE "fhir".contact_system AS ENUM ('email','fax','phone','url');
CREATE TYPE "fhir".contact_use AS ENUM ('home','mobile','old','temp','work');
CREATE TYPE "fhir".address_use AS ENUM ('home','old','temp','work');
CREATE TYPE "fhir".name_use AS ENUM ('anonymous','maiden','nickname','official','old','temp','usual');
CREATE TYPE "fhir".document_reference_status AS ENUM ('current','error','superceded');
CREATE TYPE "fhir".observation_status AS ENUM ('amended','cancelled','final','interim','registered','withdrawn');
CREATE TYPE "fhir".value_set_status AS ENUM ('active','draft','retired');
CREATE TABLE "fhir".patient (
"birth_date" timestamp,
"deceased_boolean" boolean,
"deceased_date_time" timestamp,
"multiple_birth_boolean" boolean,
"multiple_birth_integer" integer,
"care_provider_id" uuid,
"care_provider_type" fhir.resource_type,
"care_provider_display" varchar,
"care_provider_reference" varchar,
"care_provider_inlined" boolean,
"managing_organization_id" uuid,
"managing_organization_type" fhir.resource_type,
"managing_organization_display" varchar,
"managing_organization_reference" varchar,
"managing_organization_inlined" boolean,
"active" boolean,
"resource_type" fhir.resource_type,
 PRIMARY KEY(id)) INHERITS ("fhir".resources);
CREATE TABLE "fhir".patient_text (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_identifier (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_identifier_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_identifier_id" uuid references fhir.patient_identifier(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_name (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar[],
"given" varchar[],
"prefix" varchar[],
"suffix" varchar[],
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_name_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_name_id" uuid references fhir.patient_name(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_telecom (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_telecom_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_telecom_id" uuid references fhir.patient_telecom(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_gender (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_gender_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_gender_id" uuid references fhir.patient_gender(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_address (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar[],
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_address_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_address_id" uuid references fhir.patient_address(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_marital_status (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_marital_status_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_marital_status_id" uuid references fhir.patient_marital_status(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_photo (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"content_type" varchar,
"language" varchar,
"data" bytea,
"url" varchar,
"size" integer,
"hash" bytea,
"title" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"organization_id" uuid,
"organization_type" fhir.resource_type,
"organization_display" varchar,
"organization_reference" varchar,
"organization_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_relationship (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_id" uuid references fhir.patient_contact(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_relationship_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_relationship_id" uuid references fhir.patient_contact_relationship(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_name (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_id" uuid references fhir.patient_contact(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar[],
"given" varchar[],
"prefix" varchar[],
"suffix" varchar[],
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_name_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_name_id" uuid references fhir.patient_contact_name(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_telecom (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_id" uuid references fhir.patient_contact(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_telecom_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_telecom_id" uuid references fhir.patient_contact_telecom(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_address (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_id" uuid references fhir.patient_contact(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar[],
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_address_period (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_address_id" uuid references fhir.patient_contact_address(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_gender (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_id" uuid references fhir.patient_contact(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_gender_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_contact_gender_id" uuid references fhir.patient_contact_gender(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_species (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_animal_id" uuid references fhir.patient_animal(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_species_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_animal_species_id" uuid references fhir.patient_animal_species(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_breed (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_animal_id" uuid references fhir.patient_animal(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_breed_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_animal_breed_id" uuid references fhir.patient_animal_breed(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_gender_status (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_animal_id" uuid references fhir.patient_animal(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_gender_status_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_animal_gender_status_id" uuid references fhir.patient_animal_gender_status(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_communication (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_communication_coding (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"patient_communication_id" uuid references fhir.patient_communication(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_link (
"id" uuid,
"patient_id" uuid references fhir.patient(id),
"other_id" uuid,
"other_type" fhir.resource_type,
"other_display" varchar,
"other_reference" varchar,
"other_inlined" boolean,
"type" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization (
"name" varchar,
"part_of_id" uuid,
"part_of_type" fhir.resource_type,
"part_of_display" varchar,
"part_of_reference" varchar,
"part_of_inlined" boolean,
"active" boolean,
"resource_type" fhir.resource_type,
 PRIMARY KEY(id)) INHERITS ("fhir".resources);
CREATE TABLE "fhir".organization_text (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_identifier (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_identifier_period (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_identifier_id" uuid references fhir.organization_identifier(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_type (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_type_coding (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_type_id" uuid references fhir.organization_type(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_telecom (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_telecom_period (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_telecom_id" uuid references fhir.organization_telecom(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_address (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar[],
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_address_period (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_address_id" uuid references fhir.organization_address(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_purpose (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_id" uuid references fhir.organization_contact(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_purpose_coding (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_purpose_id" uuid references fhir.organization_contact_purpose(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_name (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_id" uuid references fhir.organization_contact(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar[],
"given" varchar[],
"prefix" varchar[],
"suffix" varchar[],
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_name_period (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_name_id" uuid references fhir.organization_contact_name(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_telecom (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_id" uuid references fhir.organization_contact(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_telecom_period (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_telecom_id" uuid references fhir.organization_contact_telecom(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_address (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_id" uuid references fhir.organization_contact(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar[],
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_address_period (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_address_id" uuid references fhir.organization_contact_address(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_gender (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_id" uuid references fhir.organization_contact(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_gender_coding (
"id" uuid,
"organization_id" uuid references fhir.organization(id),
"organization_contact_gender_id" uuid references fhir.organization_contact_gender(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner (
"birth_date" timestamp,
"organization_id" uuid,
"organization_type" fhir.resource_type,
"organization_display" varchar,
"organization_reference" varchar,
"organization_inlined" boolean,
"resource_type" fhir.resource_type,
 PRIMARY KEY(id)) INHERITS ("fhir".resources);
CREATE TABLE "fhir".practitioner_text (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_identifier (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_identifier_period (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_identifier_id" uuid references fhir.practitioner_identifier(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_name (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar[],
"given" varchar[],
"prefix" varchar[],
"suffix" varchar[],
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_name_period (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_name_id" uuid references fhir.practitioner_name(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_telecom (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_telecom_period (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_telecom_id" uuid references fhir.practitioner_telecom(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_address (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar[],
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_address_period (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_address_id" uuid references fhir.practitioner_address(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_gender (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_gender_coding (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_gender_id" uuid references fhir.practitioner_gender(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_photo (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"content_type" varchar,
"language" varchar,
"data" bytea,
"url" varchar,
"size" integer,
"hash" bytea,
"title" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_role (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_role_coding (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_role_id" uuid references fhir.practitioner_role(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_specialty (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_specialty_coding (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_specialty_id" uuid references fhir.practitioner_specialty(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_period (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"issuer_id" uuid,
"issuer_type" fhir.resource_type,
"issuer_display" varchar,
"issuer_reference" varchar,
"issuer_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification_code (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_qualification_id" uuid references fhir.practitioner_qualification(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification_code_coding (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_qualification_code_id" uuid references fhir.practitioner_qualification_code(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification_period (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_qualification_id" uuid references fhir.practitioner_qualification(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_communication (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_communication_coding (
"id" uuid,
"practitioner_id" uuid references fhir.practitioner(id),
"practitioner_communication_id" uuid references fhir.practitioner_communication(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter (
"status" varchar,
"class" varchar,
"subject_id" uuid,
"subject_type" fhir.resource_type,
"subject_display" varchar,
"subject_reference" varchar,
"subject_inlined" boolean,
"fulfills_id" uuid,
"fulfills_type" fhir.resource_type,
"fulfills_display" varchar,
"fulfills_reference" varchar,
"fulfills_inlined" boolean,
"start" timestamp,
"indication_id" uuid,
"indication_type" fhir.resource_type,
"indication_display" varchar,
"indication_reference" varchar,
"indication_inlined" boolean,
"service_provider_id" uuid,
"service_provider_type" fhir.resource_type,
"service_provider_display" varchar,
"service_provider_reference" varchar,
"service_provider_inlined" boolean,
"part_of_id" uuid,
"part_of_type" fhir.resource_type,
"part_of_display" varchar,
"part_of_reference" varchar,
"part_of_inlined" boolean,
"resource_type" fhir.resource_type,
 PRIMARY KEY(id)) INHERITS ("fhir".resources);
CREATE TABLE "fhir".encounter_text (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_identifier (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_identifier_period (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_identifier_id" uuid references fhir.encounter_identifier(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_type (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_type_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_type_id" uuid references fhir.encounter_type(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_participant (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"type" varchar[],
"practitioner_id" uuid,
"practitioner_type" fhir.resource_type,
"practitioner_display" varchar,
"practitioner_reference" varchar,
"practitioner_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_length (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"value" decimal,
"comparator" fhir.quantity_compararator,
"units" varchar,
"system" varchar,
"code" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_reason (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_reason_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_reason_id" uuid references fhir.encounter_reason(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_priority (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_priority_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_priority_id" uuid references fhir.encounter_priority(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"origin_id" uuid,
"origin_type" fhir.resource_type,
"origin_display" varchar,
"origin_reference" varchar,
"origin_inlined" boolean,
"destination_id" uuid,
"destination_type" fhir.resource_type,
"destination_display" varchar,
"destination_reference" varchar,
"destination_inlined" boolean,
"re_admission" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_pre_admission_identifier (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_pre_admission_identifier_period (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_pre_admission_identifier_id" uuid references fhir.encounter_hospitalization_pre_admission_identifier(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_admit_source (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_admit_source_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_admit_source_id" uuid references fhir.encounter_hospitalization_admit_source(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_period (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_accomodation (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"bed_id" uuid,
"bed_type" fhir.resource_type,
"bed_display" varchar,
"bed_reference" varchar,
"bed_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_accomodation_period (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_accomodation_id" uuid references fhir.encounter_hospitalization_accomodation(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_diet (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_diet_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_diet_id" uuid references fhir.encounter_hospitalization_diet(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_courtesy (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_courtesy_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_special_courtesy_id" uuid references fhir.encounter_hospitalization_special_courtesy(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_arrangement (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_arrangement_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_special_arrangement_id" uuid references fhir.encounter_hospitalization_special_arrangement(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_discharge_disposition (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalization(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_discharge_disposition_coding (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_hospitalization_discharge_disposition_id" uuid references fhir.encounter_hospitalization_discharge_disposition(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_location (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_location_period (
"id" uuid,
"encounter_id" uuid references fhir.encounter(id),
"encounter_location_id" uuid references fhir.encounter_location(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE INDEX pat_tex_pat_id_idx ON "fhir".patient_text (patient_id);
CREATE INDEX pat_ide_pat_id_idx ON "fhir".patient_identifier (patient_id);
CREATE INDEX pat_ide_per_pat_id_idx ON "fhir".patient_identifier_period (patient_id);
CREATE INDEX pat_ide_per_pat_ide_id_idx ON "fhir".patient_identifier_period (patient_identifier_id);
CREATE INDEX pat_nam_pat_id_idx ON "fhir".patient_name (patient_id);
CREATE INDEX pat_nam_per_pat_id_idx ON "fhir".patient_name_period (patient_id);
CREATE INDEX pat_nam_per_pat_nam_id_idx ON "fhir".patient_name_period (patient_name_id);
CREATE INDEX pat_tel_pat_id_idx ON "fhir".patient_telecom (patient_id);
CREATE INDEX pat_tel_per_pat_id_idx ON "fhir".patient_telecom_period (patient_id);
CREATE INDEX pat_tel_per_pat_tel_id_idx ON "fhir".patient_telecom_period (patient_telecom_id);
CREATE INDEX pat_gen_pat_id_idx ON "fhir".patient_gender (patient_id);
CREATE INDEX pat_gen_cod_pat_id_idx ON "fhir".patient_gender_coding (patient_id);
CREATE INDEX pat_gen_cod_pat_gen_id_idx ON "fhir".patient_gender_coding (patient_gender_id);
CREATE INDEX pat_add_pat_id_idx ON "fhir".patient_address (patient_id);
CREATE INDEX pat_add_per_pat_id_idx ON "fhir".patient_address_period (patient_id);
CREATE INDEX pat_add_per_pat_add_id_idx ON "fhir".patient_address_period (patient_address_id);
CREATE INDEX pat_mar_sta_pat_id_idx ON "fhir".patient_marital_status (patient_id);
CREATE INDEX pat_mar_sta_cod_pat_id_idx ON "fhir".patient_marital_status_coding (patient_id);
CREATE INDEX pat_mar_sta_cod_pat_mar_sta_id_idx ON "fhir".patient_marital_status_coding (patient_marital_status_id);
CREATE INDEX pat_pho_pat_id_idx ON "fhir".patient_photo (patient_id);
CREATE INDEX pat_con_pat_id_idx ON "fhir".patient_contact (patient_id);
CREATE INDEX pat_con_rel_pat_id_idx ON "fhir".patient_contact_relationship (patient_id);
CREATE INDEX pat_con_rel_pat_con_id_idx ON "fhir".patient_contact_relationship (patient_contact_id);
CREATE INDEX pat_con_rel_cod_pat_id_idx ON "fhir".patient_contact_relationship_coding (patient_id);
CREATE INDEX pat_con_rel_cod_pat_con_rel_id_idx ON "fhir".patient_contact_relationship_coding (patient_contact_relationship_id);
CREATE INDEX pat_con_nam_pat_id_idx ON "fhir".patient_contact_name (patient_id);
CREATE INDEX pat_con_nam_pat_con_id_idx ON "fhir".patient_contact_name (patient_contact_id);
CREATE INDEX pat_con_nam_per_pat_id_idx ON "fhir".patient_contact_name_period (patient_id);
CREATE INDEX pat_con_nam_per_pat_con_nam_id_idx ON "fhir".patient_contact_name_period (patient_contact_name_id);
CREATE INDEX pat_con_tel_pat_id_idx ON "fhir".patient_contact_telecom (patient_id);
CREATE INDEX pat_con_tel_pat_con_id_idx ON "fhir".patient_contact_telecom (patient_contact_id);
CREATE INDEX pat_con_tel_per_pat_id_idx ON "fhir".patient_contact_telecom_period (patient_id);
CREATE INDEX pat_con_tel_per_pat_con_tel_id_idx ON "fhir".patient_contact_telecom_period (patient_contact_telecom_id);
CREATE INDEX pat_con_add_pat_id_idx ON "fhir".patient_contact_address (patient_id);
CREATE INDEX pat_con_add_pat_con_id_idx ON "fhir".patient_contact_address (patient_contact_id);
CREATE INDEX pat_con_add_per_pat_id_idx ON "fhir".patient_contact_address_period (patient_id);
CREATE INDEX pat_con_add_per_pat_con_add_id_idx ON "fhir".patient_contact_address_period (patient_contact_address_id);
CREATE INDEX pat_con_gen_pat_id_idx ON "fhir".patient_contact_gender (patient_id);
CREATE INDEX pat_con_gen_pat_con_id_idx ON "fhir".patient_contact_gender (patient_contact_id);
CREATE INDEX pat_con_gen_cod_pat_id_idx ON "fhir".patient_contact_gender_coding (patient_id);
CREATE INDEX pat_con_gen_cod_pat_con_gen_id_idx ON "fhir".patient_contact_gender_coding (patient_contact_gender_id);
CREATE INDEX pat_ani_pat_id_idx ON "fhir".patient_animal (patient_id);
CREATE INDEX pat_ani_spe_pat_id_idx ON "fhir".patient_animal_species (patient_id);
CREATE INDEX pat_ani_spe_pat_ani_id_idx ON "fhir".patient_animal_species (patient_animal_id);
CREATE INDEX pat_ani_spe_cod_pat_id_idx ON "fhir".patient_animal_species_coding (patient_id);
CREATE INDEX pat_ani_spe_cod_pat_ani_spe_id_idx ON "fhir".patient_animal_species_coding (patient_animal_species_id);
CREATE INDEX pat_ani_bre_pat_id_idx ON "fhir".patient_animal_breed (patient_id);
CREATE INDEX pat_ani_bre_pat_ani_id_idx ON "fhir".patient_animal_breed (patient_animal_id);
CREATE INDEX pat_ani_bre_cod_pat_id_idx ON "fhir".patient_animal_breed_coding (patient_id);
CREATE INDEX pat_ani_bre_cod_pat_ani_bre_id_idx ON "fhir".patient_animal_breed_coding (patient_animal_breed_id);
CREATE INDEX pat_ani_gen_sta_pat_id_idx ON "fhir".patient_animal_gender_status (patient_id);
CREATE INDEX pat_ani_gen_sta_pat_ani_id_idx ON "fhir".patient_animal_gender_status (patient_animal_id);
CREATE INDEX pat_ani_gen_sta_cod_pat_id_idx ON "fhir".patient_animal_gender_status_coding (patient_id);
CREATE INDEX pat_ani_gen_sta_cod_pat_ani_gen_sta_id_idx ON "fhir".patient_animal_gender_status_coding (patient_animal_gender_status_id);
CREATE INDEX pat_com_pat_id_idx ON "fhir".patient_communication (patient_id);
CREATE INDEX pat_com_cod_pat_id_idx ON "fhir".patient_communication_coding (patient_id);
CREATE INDEX pat_com_cod_pat_com_id_idx ON "fhir".patient_communication_coding (patient_communication_id);
CREATE INDEX pat_lin_pat_id_idx ON "fhir".patient_link (patient_id);
CREATE INDEX org_tex_org_id_idx ON "fhir".organization_text (organization_id);
CREATE INDEX org_ide_org_id_idx ON "fhir".organization_identifier (organization_id);
CREATE INDEX org_ide_per_org_id_idx ON "fhir".organization_identifier_period (organization_id);
CREATE INDEX org_ide_per_org_ide_id_idx ON "fhir".organization_identifier_period (organization_identifier_id);
CREATE INDEX org_typ_org_id_idx ON "fhir".organization_type (organization_id);
CREATE INDEX org_typ_cod_org_id_idx ON "fhir".organization_type_coding (organization_id);
CREATE INDEX org_typ_cod_org_typ_id_idx ON "fhir".organization_type_coding (organization_type_id);
CREATE INDEX org_tel_org_id_idx ON "fhir".organization_telecom (organization_id);
CREATE INDEX org_tel_per_org_id_idx ON "fhir".organization_telecom_period (organization_id);
CREATE INDEX org_tel_per_org_tel_id_idx ON "fhir".organization_telecom_period (organization_telecom_id);
CREATE INDEX org_add_org_id_idx ON "fhir".organization_address (organization_id);
CREATE INDEX org_add_per_org_id_idx ON "fhir".organization_address_period (organization_id);
CREATE INDEX org_add_per_org_add_id_idx ON "fhir".organization_address_period (organization_address_id);
CREATE INDEX org_con_org_id_idx ON "fhir".organization_contact (organization_id);
CREATE INDEX org_con_pur_org_id_idx ON "fhir".organization_contact_purpose (organization_id);
CREATE INDEX org_con_pur_org_con_id_idx ON "fhir".organization_contact_purpose (organization_contact_id);
CREATE INDEX org_con_pur_cod_org_id_idx ON "fhir".organization_contact_purpose_coding (organization_id);
CREATE INDEX org_con_pur_cod_org_con_pur_id_idx ON "fhir".organization_contact_purpose_coding (organization_contact_purpose_id);
CREATE INDEX org_con_nam_org_id_idx ON "fhir".organization_contact_name (organization_id);
CREATE INDEX org_con_nam_org_con_id_idx ON "fhir".organization_contact_name (organization_contact_id);
CREATE INDEX org_con_nam_per_org_id_idx ON "fhir".organization_contact_name_period (organization_id);
CREATE INDEX org_con_nam_per_org_con_nam_id_idx ON "fhir".organization_contact_name_period (organization_contact_name_id);
CREATE INDEX org_con_tel_org_id_idx ON "fhir".organization_contact_telecom (organization_id);
CREATE INDEX org_con_tel_org_con_id_idx ON "fhir".organization_contact_telecom (organization_contact_id);
CREATE INDEX org_con_tel_per_org_id_idx ON "fhir".organization_contact_telecom_period (organization_id);
CREATE INDEX org_con_tel_per_org_con_tel_id_idx ON "fhir".organization_contact_telecom_period (organization_contact_telecom_id);
CREATE INDEX org_con_add_org_id_idx ON "fhir".organization_contact_address (organization_id);
CREATE INDEX org_con_add_org_con_id_idx ON "fhir".organization_contact_address (organization_contact_id);
CREATE INDEX org_con_add_per_org_id_idx ON "fhir".organization_contact_address_period (organization_id);
CREATE INDEX org_con_add_per_org_con_add_id_idx ON "fhir".organization_contact_address_period (organization_contact_address_id);
CREATE INDEX org_con_gen_org_id_idx ON "fhir".organization_contact_gender (organization_id);
CREATE INDEX org_con_gen_org_con_id_idx ON "fhir".organization_contact_gender (organization_contact_id);
CREATE INDEX org_con_gen_cod_org_id_idx ON "fhir".organization_contact_gender_coding (organization_id);
CREATE INDEX org_con_gen_cod_org_con_gen_id_idx ON "fhir".organization_contact_gender_coding (organization_contact_gender_id);
CREATE INDEX pra_tex_pra_id_idx ON "fhir".practitioner_text (practitioner_id);
CREATE INDEX pra_ide_pra_id_idx ON "fhir".practitioner_identifier (practitioner_id);
CREATE INDEX pra_ide_per_pra_id_idx ON "fhir".practitioner_identifier_period (practitioner_id);
CREATE INDEX pra_ide_per_pra_ide_id_idx ON "fhir".practitioner_identifier_period (practitioner_identifier_id);
CREATE INDEX pra_nam_pra_id_idx ON "fhir".practitioner_name (practitioner_id);
CREATE INDEX pra_nam_per_pra_id_idx ON "fhir".practitioner_name_period (practitioner_id);
CREATE INDEX pra_nam_per_pra_nam_id_idx ON "fhir".practitioner_name_period (practitioner_name_id);
CREATE INDEX pra_tel_pra_id_idx ON "fhir".practitioner_telecom (practitioner_id);
CREATE INDEX pra_tel_per_pra_id_idx ON "fhir".practitioner_telecom_period (practitioner_id);
CREATE INDEX pra_tel_per_pra_tel_id_idx ON "fhir".practitioner_telecom_period (practitioner_telecom_id);
CREATE INDEX pra_add_pra_id_idx ON "fhir".practitioner_address (practitioner_id);
CREATE INDEX pra_add_per_pra_id_idx ON "fhir".practitioner_address_period (practitioner_id);
CREATE INDEX pra_add_per_pra_add_id_idx ON "fhir".practitioner_address_period (practitioner_address_id);
CREATE INDEX pra_gen_pra_id_idx ON "fhir".practitioner_gender (practitioner_id);
CREATE INDEX pra_gen_cod_pra_id_idx ON "fhir".practitioner_gender_coding (practitioner_id);
CREATE INDEX pra_gen_cod_pra_gen_id_idx ON "fhir".practitioner_gender_coding (practitioner_gender_id);
CREATE INDEX pra_pho_pra_id_idx ON "fhir".practitioner_photo (practitioner_id);
CREATE INDEX pra_rol_pra_id_idx ON "fhir".practitioner_role (practitioner_id);
CREATE INDEX pra_rol_cod_pra_id_idx ON "fhir".practitioner_role_coding (practitioner_id);
CREATE INDEX pra_rol_cod_pra_rol_id_idx ON "fhir".practitioner_role_coding (practitioner_role_id);
CREATE INDEX pra_spe_pra_id_idx ON "fhir".practitioner_specialty (practitioner_id);
CREATE INDEX pra_spe_cod_pra_id_idx ON "fhir".practitioner_specialty_coding (practitioner_id);
CREATE INDEX pra_spe_cod_pra_spe_id_idx ON "fhir".practitioner_specialty_coding (practitioner_specialty_id);
CREATE INDEX pra_per_pra_id_idx ON "fhir".practitioner_period (practitioner_id);
CREATE INDEX pra_qua_pra_id_idx ON "fhir".practitioner_qualification (practitioner_id);
CREATE INDEX pra_qua_cod_pra_id_idx ON "fhir".practitioner_qualification_code (practitioner_id);
CREATE INDEX pra_qua_cod_pra_qua_id_idx ON "fhir".practitioner_qualification_code (practitioner_qualification_id);
CREATE INDEX pra_qua_cod_cod_pra_id_idx ON "fhir".practitioner_qualification_code_coding (practitioner_id);
CREATE INDEX pra_qua_cod_cod_pra_qua_cod_id_idx ON "fhir".practitioner_qualification_code_coding (practitioner_qualification_code_id);
CREATE INDEX pra_qua_per_pra_id_idx ON "fhir".practitioner_qualification_period (practitioner_id);
CREATE INDEX pra_qua_per_pra_qua_id_idx ON "fhir".practitioner_qualification_period (practitioner_qualification_id);
CREATE INDEX pra_com_pra_id_idx ON "fhir".practitioner_communication (practitioner_id);
CREATE INDEX pra_com_cod_pra_id_idx ON "fhir".practitioner_communication_coding (practitioner_id);
CREATE INDEX pra_com_cod_pra_com_id_idx ON "fhir".practitioner_communication_coding (practitioner_communication_id);
CREATE INDEX enc_tex_enc_id_idx ON "fhir".encounter_text (encounter_id);
CREATE INDEX enc_ide_enc_id_idx ON "fhir".encounter_identifier (encounter_id);
CREATE INDEX enc_ide_per_enc_id_idx ON "fhir".encounter_identifier_period (encounter_id);
CREATE INDEX enc_ide_per_enc_ide_id_idx ON "fhir".encounter_identifier_period (encounter_identifier_id);
CREATE INDEX enc_typ_enc_id_idx ON "fhir".encounter_type (encounter_id);
CREATE INDEX enc_typ_cod_enc_id_idx ON "fhir".encounter_type_coding (encounter_id);
CREATE INDEX enc_typ_cod_enc_typ_id_idx ON "fhir".encounter_type_coding (encounter_type_id);
CREATE INDEX enc_par_enc_id_idx ON "fhir".encounter_participant (encounter_id);
CREATE INDEX enc_len_enc_id_idx ON "fhir".encounter_length (encounter_id);
CREATE INDEX enc_rea_enc_id_idx ON "fhir".encounter_reason (encounter_id);
CREATE INDEX enc_rea_cod_enc_id_idx ON "fhir".encounter_reason_coding (encounter_id);
CREATE INDEX enc_rea_cod_enc_rea_id_idx ON "fhir".encounter_reason_coding (encounter_reason_id);
CREATE INDEX enc_pri_enc_id_idx ON "fhir".encounter_priority (encounter_id);
CREATE INDEX enc_pri_cod_enc_id_idx ON "fhir".encounter_priority_coding (encounter_id);
CREATE INDEX enc_pri_cod_enc_pri_id_idx ON "fhir".encounter_priority_coding (encounter_priority_id);
CREATE INDEX enc_hos_enc_id_idx ON "fhir".encounter_hospitalization (encounter_id);
CREATE INDEX enc_hos_pre_adm_ide_enc_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifier (encounter_id);
CREATE INDEX enc_hos_pre_adm_ide_enc_hos_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifier (encounter_hospitalization_id);
CREATE INDEX enc_hos_pre_adm_ide_per_enc_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifier_period (encounter_id);
CREATE INDEX enc_hos_pre_adm_ide_per_enc_hos_pre_adm_ide_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifier_period (encounter_hospitalization_pre_admission_identifier_id);
CREATE INDEX enc_hos_adm_sou_enc_id_idx ON "fhir".encounter_hospitalization_admit_source (encounter_id);
CREATE INDEX enc_hos_adm_sou_enc_hos_id_idx ON "fhir".encounter_hospitalization_admit_source (encounter_hospitalization_id);
CREATE INDEX enc_hos_adm_sou_cod_enc_id_idx ON "fhir".encounter_hospitalization_admit_source_coding (encounter_id);
CREATE INDEX enc_hos_adm_sou_cod_enc_hos_adm_sou_id_idx ON "fhir".encounter_hospitalization_admit_source_coding (encounter_hospitalization_admit_source_id);
CREATE INDEX enc_hos_per_enc_id_idx ON "fhir".encounter_hospitalization_period (encounter_id);
CREATE INDEX enc_hos_per_enc_hos_id_idx ON "fhir".encounter_hospitalization_period (encounter_hospitalization_id);
CREATE INDEX enc_hos_acc_enc_id_idx ON "fhir".encounter_hospitalization_accomodation (encounter_id);
CREATE INDEX enc_hos_acc_enc_hos_id_idx ON "fhir".encounter_hospitalization_accomodation (encounter_hospitalization_id);
CREATE INDEX enc_hos_acc_per_enc_id_idx ON "fhir".encounter_hospitalization_accomodation_period (encounter_id);
CREATE INDEX enc_hos_acc_per_enc_hos_acc_id_idx ON "fhir".encounter_hospitalization_accomodation_period (encounter_hospitalization_accomodation_id);
CREATE INDEX enc_hos_die_enc_id_idx ON "fhir".encounter_hospitalization_diet (encounter_id);
CREATE INDEX enc_hos_die_enc_hos_id_idx ON "fhir".encounter_hospitalization_diet (encounter_hospitalization_id);
CREATE INDEX enc_hos_die_cod_enc_id_idx ON "fhir".encounter_hospitalization_diet_coding (encounter_id);
CREATE INDEX enc_hos_die_cod_enc_hos_die_id_idx ON "fhir".encounter_hospitalization_diet_coding (encounter_hospitalization_diet_id);
CREATE INDEX enc_hos_spe_cou_enc_id_idx ON "fhir".encounter_hospitalization_special_courtesy (encounter_id);
CREATE INDEX enc_hos_spe_cou_enc_hos_id_idx ON "fhir".encounter_hospitalization_special_courtesy (encounter_hospitalization_id);
CREATE INDEX enc_hos_spe_cou_cod_enc_id_idx ON "fhir".encounter_hospitalization_special_courtesy_coding (encounter_id);
CREATE INDEX enc_hos_spe_cou_cod_enc_hos_spe_cou_id_idx ON "fhir".encounter_hospitalization_special_courtesy_coding (encounter_hospitalization_special_courtesy_id);
CREATE INDEX enc_hos_spe_arr_enc_id_idx ON "fhir".encounter_hospitalization_special_arrangement (encounter_id);
CREATE INDEX enc_hos_spe_arr_enc_hos_id_idx ON "fhir".encounter_hospitalization_special_arrangement (encounter_hospitalization_id);
CREATE INDEX enc_hos_spe_arr_cod_enc_id_idx ON "fhir".encounter_hospitalization_special_arrangement_coding (encounter_id);
CREATE INDEX enc_hos_spe_arr_cod_enc_hos_spe_arr_id_idx ON "fhir".encounter_hospitalization_special_arrangement_coding (encounter_hospitalization_special_arrangement_id);
CREATE INDEX enc_hos_dis_dis_enc_id_idx ON "fhir".encounter_hospitalization_discharge_disposition (encounter_id);
CREATE INDEX enc_hos_dis_dis_enc_hos_id_idx ON "fhir".encounter_hospitalization_discharge_disposition (encounter_hospitalization_id);
CREATE INDEX enc_hos_dis_dis_cod_enc_id_idx ON "fhir".encounter_hospitalization_discharge_disposition_coding (encounter_id);
CREATE INDEX enc_hos_dis_dis_cod_enc_hos_dis_dis_id_idx ON "fhir".encounter_hospitalization_discharge_disposition_coding (encounter_hospitalization_discharge_disposition_id);
CREATE INDEX enc_loc_enc_id_idx ON "fhir".encounter_location (encounter_id);
CREATE INDEX enc_loc_per_enc_id_idx ON "fhir".encounter_location_period (encounter_id);
CREATE INDEX enc_loc_per_enc_loc_id_idx ON "fhir".encounter_location_period (encounter_location_id);
CREATE VIEW "fhir".view_patient AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.patient_text t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as text,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.patient_identifier_period t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.patient_identifier t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as identifier,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.patient_name_period t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.family,t2.given,t2.prefix,t2.suffix
          from fhir.patient_name t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as name,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.patient_telecom_period t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.system,t2.value,t2.use
          from fhir.patient_telecom t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as telecom,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.patient_gender_coding t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.patient_gender t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as gender,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.patient_address_period t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
          from fhir.patient_address t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as address,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.patient_marital_status_coding t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.patient_marital_status t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as marital_status,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.content_type,t2.language,t2.data,t2.url,t2.size,t2.hash,t2.title
          from fhir.patient_photo t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as photo,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.patient_contact_relationship_coding t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_relationship_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_contact_relationship t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as relationship,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.patient_contact_name_period t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_name_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.family,t3.given,t3.prefix,t3.suffix
              from fhir.patient_contact_name t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as name,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.patient_contact_telecom_period t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_telecom_id = t3.id
                ) t4
             ) as period, t3.system,t3.value,t3.use
              from fhir.patient_contact_telecom t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as telecom,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.patient_contact_address_period t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_address_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.line,t3.city,t3.state,t3.zip,t3.country
              from fhir.patient_contact_address t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as address,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.patient_contact_gender_coding t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_gender_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_contact_gender t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as gender, hstore_to_json(hstore(ARRAY['reference', t2.organization_reference ,'display',t2.organization_display])) as organization
          from fhir.patient_contact t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as contact,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.patient_animal_species_coding t4
                  WHERE t4.patient_id = t1.id AND t4.patient_animal_species_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_animal_species t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as species,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.patient_animal_breed_coding t4
                  WHERE t4.patient_id = t1.id AND t4.patient_animal_breed_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_animal_breed t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as breed,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.patient_animal_gender_status_coding t4
                  WHERE t4.patient_id = t1.id AND t4.patient_animal_gender_status_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_animal_gender_status t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as gender_status
          from fhir.patient_animal t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as animal,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.patient_communication_coding t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.patient_communication t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as communication,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.type, hstore_to_json(hstore(ARRAY['reference', t2.other_reference ,'display',t2.other_display])) as other
          from fhir.patient_link t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as link, t1.birth_date,t1.deceased_boolean,t1.deceased_date_time,t1.multiple_birth_boolean,t1.multiple_birth_integer,t1.active,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.care_provider_reference ,'display',t1.care_provider_display])) as care_provider,hstore_to_json(hstore(ARRAY['reference', t1.managing_organization_reference ,'display',t1.managing_organization_display])) as managing_organization
  from fhir.patient t1
) t1
;
CREATE VIEW "fhir".view_organization AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.organization_text t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as text,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.organization_identifier_period t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.organization_identifier t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as identifier,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.organization_type_coding t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.organization_type t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as type,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.organization_telecom_period t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as period, t2.system,t2.value,t2.use
          from fhir.organization_telecom t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as telecom,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.organization_address_period t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
          from fhir.organization_address t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as address,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.organization_contact_purpose_coding t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_purpose_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.organization_contact_purpose t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as purpose,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.organization_contact_name_period t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_name_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.family,t3.given,t3.prefix,t3.suffix
              from fhir.organization_contact_name t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as name,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.organization_contact_telecom_period t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_telecom_id = t3.id
                ) t4
             ) as period, t3.system,t3.value,t3.use
              from fhir.organization_contact_telecom t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as telecom,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.organization_contact_address_period t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_address_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.line,t3.city,t3.state,t3.zip,t3.country
              from fhir.organization_contact_address t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as address,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.organization_contact_gender_coding t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_gender_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.organization_contact_gender t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as gender
          from fhir.organization_contact t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as contact, t1.name,t1.active,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.part_of_reference ,'display',t1.part_of_display])) as part_of
  from fhir.organization t1
) t1
;
CREATE VIEW "fhir".view_practitioner AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.practitioner_text t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as text,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.practitioner_identifier_period t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.practitioner_identifier t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as identifier,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.practitioner_name_period t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.family,t2.given,t2.prefix,t2.suffix
          from fhir.practitioner_name t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as name,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.practitioner_telecom_period t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.system,t2.value,t2.use
          from fhir.practitioner_telecom t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as telecom,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.practitioner_address_period t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
          from fhir.practitioner_address t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as address,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.practitioner_gender_coding t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_gender t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as gender,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.content_type,t2.language,t2.data,t2.url,t2.size,t2.hash,t2.title
          from fhir.practitioner_photo t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as photo,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.practitioner_role_coding t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_role t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as role,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.practitioner_specialty_coding t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_specialty t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as specialty,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.start,t2.end
          from fhir.practitioner_period t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as period,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.practitioner_qualification_code_coding t4
                  WHERE t4.practitioner_id = t1.id AND t4.practitioner_qualification_code_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.practitioner_qualification_code t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as code,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.practitioner_qualification_period t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, hstore_to_json(hstore(ARRAY['reference', t2.issuer_reference ,'display',t2.issuer_display])) as issuer
          from fhir.practitioner_qualification t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as qualification,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.practitioner_communication_coding t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_communication t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as communication, t1.birth_date,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.organization_reference ,'display',t1.organization_display])) as organization
  from fhir.practitioner t1
) t1
;
CREATE VIEW "fhir".view_encounter AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.encounter_text t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as text,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.encounter_identifier_period t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.encounter_identifier t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as identifier,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.encounter_type_coding t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.encounter_type t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as type,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.type, hstore_to_json(hstore(ARRAY['reference', t2.practitioner_reference ,'display',t2.practitioner_display])) as practitioner
          from fhir.encounter_participant t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as participant,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.value,t2.comparator,t2.units,t2.system,t2.code
          from fhir.encounter_length t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as length,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.encounter_reason_coding t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.encounter_reason t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as reason,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.system,t3.version,t3.code,t3.display,t3.primary
              from fhir.encounter_priority_coding t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.encounter_priority t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as priority,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.encounter_hospitalization_pre_admission_identifier_period t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_pre_admission_identifier_id = t3.id
                ) t4
             ) as period, t3.use,t3.label,t3.system,t3.value
              from fhir.encounter_hospitalization_pre_admission_identifier t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as pre_admission_identifier,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.encounter_hospitalization_admit_source_coding t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_admit_source_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_admit_source t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as admit_source,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.encounter_hospitalization_period t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as period,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.start,t4.end
                  from fhir.encounter_hospitalization_accomodation_period t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_accomodation_id = t3.id
                ) t4
             ) as period, hstore_to_json(hstore(ARRAY['reference', t3.bed_reference ,'display',t3.bed_display])) as bed
              from fhir.encounter_hospitalization_accomodation t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as accomodation,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.encounter_hospitalization_diet_coding t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_diet_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_diet t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as diet,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.encounter_hospitalization_special_courtesy_coding t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_special_courtesy_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_special_courtesy t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as special_courtesy,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.encounter_hospitalization_special_arrangement_coding t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_special_arrangement_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_special_arrangement t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as special_arrangement,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     ( select
              array_to_json(
                array_agg(row_to_json(t4, true)), true) from
                (
                  select     t4.system,t4.version,t4.code,t4.display,t4.primary
                  from fhir.encounter_hospitalization_discharge_disposition_coding t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_discharge_disposition_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_discharge_disposition t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as discharge_disposition, t2.re_admission, hstore_to_json(hstore(ARRAY['reference', t2.origin_reference ,'display',t2.origin_display])) as origin,hstore_to_json(hstore(ARRAY['reference', t2.destination_reference ,'display',t2.destination_display])) as destination
          from fhir.encounter_hospitalization t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as hospitalization,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.encounter_location_period t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as period
          from fhir.encounter_location t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as location, t1.status,t1.class,t1.start,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.subject_reference ,'display',t1.subject_display])) as subject,hstore_to_json(hstore(ARRAY['reference', t1.fulfills_reference ,'display',t1.fulfills_display])) as fulfills,hstore_to_json(hstore(ARRAY['reference', t1.indication_reference ,'display',t1.indication_display])) as indication,hstore_to_json(hstore(ARRAY['reference', t1.service_provider_reference ,'display',t1.service_provider_display])) as service_provider,hstore_to_json(hstore(ARRAY['reference', t1.part_of_reference ,'display',t1.part_of_display])) as part_of
  from fhir.encounter t1
) t1
;