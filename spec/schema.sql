drop schema if exists fhir cascade;
create schema fhir;
CREATE TYPE "fhir".resource_type AS ENUM ('patient','organization','practitioner','encounter');
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
CREATE TABLE "fhir".patients (
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
CREATE TABLE "fhir".patient_texts (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_identifiers (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_identifier_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_identifier_id" uuid references fhir.patient_identifiers(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_names (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar,
"given" varchar,
"prefix" varchar,
"suffix" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_name_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_name_id" uuid references fhir.patient_names(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_telecoms (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_telecom_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_telecom_id" uuid references fhir.patient_telecoms(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_genders (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_gender_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_gender_id" uuid references fhir.patient_genders(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_addresses (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar,
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_address_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_address_id" uuid references fhir.patient_addresses(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_marital_statuses (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_marital_status_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_marital_status_id" uuid references fhir.patient_marital_statuses(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_photos (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"content_type" varchar,
"language" varchar,
"data" bytea,
"url" varchar,
"size" integer,
"hash" bytea,
"title" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contacts (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"organization_id" uuid,
"organization_type" fhir.resource_type,
"organization_display" varchar,
"organization_reference" varchar,
"organization_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_relationships (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_id" uuid references fhir.patient_contacts(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_relationship_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_relationship_id" uuid references fhir.patient_contact_relationships(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_names (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_id" uuid references fhir.patient_contacts(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar,
"given" varchar,
"prefix" varchar,
"suffix" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_name_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_name_id" uuid references fhir.patient_contact_names(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_telecoms (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_id" uuid references fhir.patient_contacts(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_telecom_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_telecom_id" uuid references fhir.patient_contact_telecoms(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_addresses (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_id" uuid references fhir.patient_contacts(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar,
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_address_periods (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_address_id" uuid references fhir.patient_contact_addresses(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_genders (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_id" uuid references fhir.patient_contacts(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_contact_gender_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_contact_gender_id" uuid references fhir.patient_contact_genders(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animals (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_species (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_animal_id" uuid references fhir.patient_animals(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_species_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_animal_specy_id" uuid references fhir.patient_animal_species(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_breeds (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_animal_id" uuid references fhir.patient_animals(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_breed_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_animal_breed_id" uuid references fhir.patient_animal_breeds(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_gender_statuses (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_animal_id" uuid references fhir.patient_animals(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_animal_gender_status_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_animal_gender_status_id" uuid references fhir.patient_animal_gender_statuses(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_communications (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_communication_codings (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"patient_communication_id" uuid references fhir.patient_communications(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".patient_links (
"id" uuid,
"patient_id" uuid references fhir.patients(id),
"other_id" uuid,
"other_type" fhir.resource_type,
"other_display" varchar,
"other_reference" varchar,
"other_inlined" boolean,
"type" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organizations (
"name" varchar,
"part_of_id" uuid,
"part_of_type" fhir.resource_type,
"part_of_display" varchar,
"part_of_reference" varchar,
"part_of_inlined" boolean,
"active" boolean,
"resource_type" fhir.resource_type,
 PRIMARY KEY(id)) INHERITS ("fhir".resources);
CREATE TABLE "fhir".organization_texts (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_identifiers (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_identifier_periods (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_identifier_id" uuid references fhir.organization_identifiers(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_types (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_type_codings (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_type_id" uuid references fhir.organization_types(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_telecoms (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_telecom_periods (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_telecom_id" uuid references fhir.organization_telecoms(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_addresses (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar,
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_address_periods (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_address_id" uuid references fhir.organization_addresses(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contacts (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_purposes (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_id" uuid references fhir.organization_contacts(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_purpose_codings (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_purpose_id" uuid references fhir.organization_contact_purposes(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_names (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_id" uuid references fhir.organization_contacts(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar,
"given" varchar,
"prefix" varchar,
"suffix" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_name_periods (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_name_id" uuid references fhir.organization_contact_names(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_telecoms (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_id" uuid references fhir.organization_contacts(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_telecom_periods (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_telecom_id" uuid references fhir.organization_contact_telecoms(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_addresses (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_id" uuid references fhir.organization_contacts(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar,
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_address_periods (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_address_id" uuid references fhir.organization_contact_addresses(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_genders (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_id" uuid references fhir.organization_contacts(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".organization_contact_gender_codings (
"id" uuid,
"organization_id" uuid references fhir.organizations(id),
"organization_contact_gender_id" uuid references fhir.organization_contact_genders(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioners (
"birth_date" timestamp,
"organization_id" uuid,
"organization_type" fhir.resource_type,
"organization_display" varchar,
"organization_reference" varchar,
"organization_inlined" boolean,
"resource_type" fhir.resource_type,
 PRIMARY KEY(id)) INHERITS ("fhir".resources);
CREATE TABLE "fhir".practitioner_texts (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_identifiers (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_identifier_periods (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_identifier_id" uuid references fhir.practitioner_identifiers(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_names (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"use" fhir.name_use,
"text" varchar,
"family" varchar,
"given" varchar,
"prefix" varchar,
"suffix" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_name_periods (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_name_id" uuid references fhir.practitioner_names(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_telecoms (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"system" fhir.contact_system,
"value" varchar,
"use" fhir.contact_use,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_telecom_periods (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_telecom_id" uuid references fhir.practitioner_telecoms(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_addresses (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"use" fhir.address_use,
"text" varchar,
"line" varchar,
"city" varchar,
"state" varchar,
"zip" varchar,
"country" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_address_periods (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_address_id" uuid references fhir.practitioner_addresses(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_genders (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_gender_codings (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_gender_id" uuid references fhir.practitioner_genders(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_photos (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"content_type" varchar,
"language" varchar,
"data" bytea,
"url" varchar,
"size" integer,
"hash" bytea,
"title" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_roles (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_role_codings (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_role_id" uuid references fhir.practitioner_roles(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_specialties (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_specialty_codings (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_specialty_id" uuid references fhir.practitioner_specialties(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_periods (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualifications (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"issuer_id" uuid,
"issuer_type" fhir.resource_type,
"issuer_display" varchar,
"issuer_reference" varchar,
"issuer_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification_codes (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_qualification_id" uuid references fhir.practitioner_qualifications(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification_code_codings (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_qualification_code_id" uuid references fhir.practitioner_qualification_codes(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_qualification_periods (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_qualification_id" uuid references fhir.practitioner_qualifications(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_communications (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".practitioner_communication_codings (
"id" uuid,
"practitioner_id" uuid references fhir.practitioners(id),
"practitioner_communication_id" uuid references fhir.practitioner_communications(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounters (
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
CREATE TABLE "fhir".encounter_texts (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"status" fhir.narrative_status,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_identifiers (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_identifier_periods (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_identifier_id" uuid references fhir.encounter_identifiers(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_types (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_type_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_type_id" uuid references fhir.encounter_types(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_participants (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"type" varchar,
"practitioner_id" uuid,
"practitioner_type" fhir.resource_type,
"practitioner_display" varchar,
"practitioner_reference" varchar,
"practitioner_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_lengths (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"value" decimal,
"comparator" fhir.quantity_compararator,
"units" varchar,
"system" varchar,
"code" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_reasons (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_reason_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_reason_id" uuid references fhir.encounter_reasons(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_priorities (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_priority_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_priority_id" uuid references fhir.encounter_priorities(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalizations (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
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
CREATE TABLE "fhir".encounter_hospitalization_pre_admission_identifiers (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"use" fhir.identifier_use,
"label" varchar,
"system" varchar,
"value" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_pre_admission_identifier_periods (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_pre_admission_identifier_id" uuid references fhir.encounter_hospitalization_pre_admission_identifiers(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_admit_sources (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_admit_source_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_admit_source_id" uuid references fhir.encounter_hospitalization_admit_sources(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_periods (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_accomodations (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"bed_id" uuid,
"bed_type" fhir.resource_type,
"bed_display" varchar,
"bed_reference" varchar,
"bed_inlined" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_accomodation_periods (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_accomodation_id" uuid references fhir.encounter_hospitalization_accomodations(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_diets (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_diet_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_diet_id" uuid references fhir.encounter_hospitalization_diets(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_courtesies (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_courtesy_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_special_courtesy_id" uuid references fhir.encounter_hospitalization_special_courtesies(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_arrangements (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_special_arrangement_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_special_arrangement_id" uuid references fhir.encounter_hospitalization_special_arrangements(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_discharge_dispositions (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_id" uuid references fhir.encounter_hospitalizations(id),
"text" varchar,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_hospitalization_discharge_disposition_codings (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_hospitalization_discharge_disposition_id" uuid references fhir.encounter_hospitalization_discharge_dispositions(id),
"system" varchar,
"version" varchar,
"code" varchar,
"display" varchar,
"primary" boolean,
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_locations (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
 PRIMARY KEY(id)) ;
CREATE TABLE "fhir".encounter_location_periods (
"id" uuid,
"encounter_id" uuid references fhir.encounters(id),
"encounter_location_id" uuid references fhir.encounter_locations(id),
"start" timestamp,
"end" timestamp,
 PRIMARY KEY(id)) ;
CREATE INDEX pat_tex_pat_id_idx ON "fhir".patient_texts (patient_id);
CREATE INDEX pat_ide_pat_id_idx ON "fhir".patient_identifiers (patient_id);
CREATE INDEX pat_ide_per_pat_id_idx ON "fhir".patient_identifier_periods (patient_id);
CREATE INDEX pat_ide_per_pat_ide_id_idx ON "fhir".patient_identifier_periods (patient_identifier_id);
CREATE INDEX pat_nam_pat_id_idx ON "fhir".patient_names (patient_id);
CREATE INDEX pat_nam_per_pat_id_idx ON "fhir".patient_name_periods (patient_id);
CREATE INDEX pat_nam_per_pat_nam_id_idx ON "fhir".patient_name_periods (patient_name_id);
CREATE INDEX pat_tel_pat_id_idx ON "fhir".patient_telecoms (patient_id);
CREATE INDEX pat_tel_per_pat_id_idx ON "fhir".patient_telecom_periods (patient_id);
CREATE INDEX pat_tel_per_pat_tel_id_idx ON "fhir".patient_telecom_periods (patient_telecom_id);
CREATE INDEX pat_gen_pat_id_idx ON "fhir".patient_genders (patient_id);
CREATE INDEX pat_gen_cod_pat_id_idx ON "fhir".patient_gender_codings (patient_id);
CREATE INDEX pat_gen_cod_pat_gen_id_idx ON "fhir".patient_gender_codings (patient_gender_id);
CREATE INDEX pat_add_pat_id_idx ON "fhir".patient_addresses (patient_id);
CREATE INDEX pat_add_per_pat_id_idx ON "fhir".patient_address_periods (patient_id);
CREATE INDEX pat_add_per_pat_add_id_idx ON "fhir".patient_address_periods (patient_address_id);
CREATE INDEX pat_mar_sta_pat_id_idx ON "fhir".patient_marital_statuses (patient_id);
CREATE INDEX pat_mar_sta_cod_pat_id_idx ON "fhir".patient_marital_status_codings (patient_id);
CREATE INDEX pat_mar_sta_cod_pat_mar_sta_id_idx ON "fhir".patient_marital_status_codings (patient_marital_status_id);
CREATE INDEX pat_pho_pat_id_idx ON "fhir".patient_photos (patient_id);
CREATE INDEX pat_con_pat_id_idx ON "fhir".patient_contacts (patient_id);
CREATE INDEX pat_con_rel_pat_id_idx ON "fhir".patient_contact_relationships (patient_id);
CREATE INDEX pat_con_rel_pat_con_id_idx ON "fhir".patient_contact_relationships (patient_contact_id);
CREATE INDEX pat_con_rel_cod_pat_id_idx ON "fhir".patient_contact_relationship_codings (patient_id);
CREATE INDEX pat_con_rel_cod_pat_con_rel_id_idx ON "fhir".patient_contact_relationship_codings (patient_contact_relationship_id);
CREATE INDEX pat_con_nam_pat_id_idx ON "fhir".patient_contact_names (patient_id);
CREATE INDEX pat_con_nam_pat_con_id_idx ON "fhir".patient_contact_names (patient_contact_id);
CREATE INDEX pat_con_nam_per_pat_id_idx ON "fhir".patient_contact_name_periods (patient_id);
CREATE INDEX pat_con_nam_per_pat_con_nam_id_idx ON "fhir".patient_contact_name_periods (patient_contact_name_id);
CREATE INDEX pat_con_tel_pat_id_idx ON "fhir".patient_contact_telecoms (patient_id);
CREATE INDEX pat_con_tel_pat_con_id_idx ON "fhir".patient_contact_telecoms (patient_contact_id);
CREATE INDEX pat_con_tel_per_pat_id_idx ON "fhir".patient_contact_telecom_periods (patient_id);
CREATE INDEX pat_con_tel_per_pat_con_tel_id_idx ON "fhir".patient_contact_telecom_periods (patient_contact_telecom_id);
CREATE INDEX pat_con_add_pat_id_idx ON "fhir".patient_contact_addresses (patient_id);
CREATE INDEX pat_con_add_pat_con_id_idx ON "fhir".patient_contact_addresses (patient_contact_id);
CREATE INDEX pat_con_add_per_pat_id_idx ON "fhir".patient_contact_address_periods (patient_id);
CREATE INDEX pat_con_add_per_pat_con_add_id_idx ON "fhir".patient_contact_address_periods (patient_contact_address_id);
CREATE INDEX pat_con_gen_pat_id_idx ON "fhir".patient_contact_genders (patient_id);
CREATE INDEX pat_con_gen_pat_con_id_idx ON "fhir".patient_contact_genders (patient_contact_id);
CREATE INDEX pat_con_gen_cod_pat_id_idx ON "fhir".patient_contact_gender_codings (patient_id);
CREATE INDEX pat_con_gen_cod_pat_con_gen_id_idx ON "fhir".patient_contact_gender_codings (patient_contact_gender_id);
CREATE INDEX pat_ani_pat_id_idx ON "fhir".patient_animals (patient_id);
CREATE INDEX pat_ani_spe_pat_id_idx ON "fhir".patient_animal_species (patient_id);
CREATE INDEX pat_ani_spe_pat_ani_id_idx ON "fhir".patient_animal_species (patient_animal_id);
CREATE INDEX pat_ani_spe_cod_pat_id_idx ON "fhir".patient_animal_species_codings (patient_id);
CREATE INDEX pat_ani_spe_cod_pat_ani_spe_id_idx ON "fhir".patient_animal_species_codings (patient_animal_specy_id);
CREATE INDEX pat_ani_bre_pat_id_idx ON "fhir".patient_animal_breeds (patient_id);
CREATE INDEX pat_ani_bre_pat_ani_id_idx ON "fhir".patient_animal_breeds (patient_animal_id);
CREATE INDEX pat_ani_bre_cod_pat_id_idx ON "fhir".patient_animal_breed_codings (patient_id);
CREATE INDEX pat_ani_bre_cod_pat_ani_bre_id_idx ON "fhir".patient_animal_breed_codings (patient_animal_breed_id);
CREATE INDEX pat_ani_gen_sta_pat_id_idx ON "fhir".patient_animal_gender_statuses (patient_id);
CREATE INDEX pat_ani_gen_sta_pat_ani_id_idx ON "fhir".patient_animal_gender_statuses (patient_animal_id);
CREATE INDEX pat_ani_gen_sta_cod_pat_id_idx ON "fhir".patient_animal_gender_status_codings (patient_id);
CREATE INDEX pat_ani_gen_sta_cod_pat_ani_gen_sta_id_idx ON "fhir".patient_animal_gender_status_codings (patient_animal_gender_status_id);
CREATE INDEX pat_com_pat_id_idx ON "fhir".patient_communications (patient_id);
CREATE INDEX pat_com_cod_pat_id_idx ON "fhir".patient_communication_codings (patient_id);
CREATE INDEX pat_com_cod_pat_com_id_idx ON "fhir".patient_communication_codings (patient_communication_id);
CREATE INDEX pat_lin_pat_id_idx ON "fhir".patient_links (patient_id);
CREATE INDEX org_tex_org_id_idx ON "fhir".organization_texts (organization_id);
CREATE INDEX org_ide_org_id_idx ON "fhir".organization_identifiers (organization_id);
CREATE INDEX org_ide_per_org_id_idx ON "fhir".organization_identifier_periods (organization_id);
CREATE INDEX org_ide_per_org_ide_id_idx ON "fhir".organization_identifier_periods (organization_identifier_id);
CREATE INDEX org_typ_org_id_idx ON "fhir".organization_types (organization_id);
CREATE INDEX org_typ_cod_org_id_idx ON "fhir".organization_type_codings (organization_id);
CREATE INDEX org_typ_cod_org_typ_id_idx ON "fhir".organization_type_codings (organization_type_id);
CREATE INDEX org_tel_org_id_idx ON "fhir".organization_telecoms (organization_id);
CREATE INDEX org_tel_per_org_id_idx ON "fhir".organization_telecom_periods (organization_id);
CREATE INDEX org_tel_per_org_tel_id_idx ON "fhir".organization_telecom_periods (organization_telecom_id);
CREATE INDEX org_add_org_id_idx ON "fhir".organization_addresses (organization_id);
CREATE INDEX org_add_per_org_id_idx ON "fhir".organization_address_periods (organization_id);
CREATE INDEX org_add_per_org_add_id_idx ON "fhir".organization_address_periods (organization_address_id);
CREATE INDEX org_con_org_id_idx ON "fhir".organization_contacts (organization_id);
CREATE INDEX org_con_pur_org_id_idx ON "fhir".organization_contact_purposes (organization_id);
CREATE INDEX org_con_pur_org_con_id_idx ON "fhir".organization_contact_purposes (organization_contact_id);
CREATE INDEX org_con_pur_cod_org_id_idx ON "fhir".organization_contact_purpose_codings (organization_id);
CREATE INDEX org_con_pur_cod_org_con_pur_id_idx ON "fhir".organization_contact_purpose_codings (organization_contact_purpose_id);
CREATE INDEX org_con_nam_org_id_idx ON "fhir".organization_contact_names (organization_id);
CREATE INDEX org_con_nam_org_con_id_idx ON "fhir".organization_contact_names (organization_contact_id);
CREATE INDEX org_con_nam_per_org_id_idx ON "fhir".organization_contact_name_periods (organization_id);
CREATE INDEX org_con_nam_per_org_con_nam_id_idx ON "fhir".organization_contact_name_periods (organization_contact_name_id);
CREATE INDEX org_con_tel_org_id_idx ON "fhir".organization_contact_telecoms (organization_id);
CREATE INDEX org_con_tel_org_con_id_idx ON "fhir".organization_contact_telecoms (organization_contact_id);
CREATE INDEX org_con_tel_per_org_id_idx ON "fhir".organization_contact_telecom_periods (organization_id);
CREATE INDEX org_con_tel_per_org_con_tel_id_idx ON "fhir".organization_contact_telecom_periods (organization_contact_telecom_id);
CREATE INDEX org_con_add_org_id_idx ON "fhir".organization_contact_addresses (organization_id);
CREATE INDEX org_con_add_org_con_id_idx ON "fhir".organization_contact_addresses (organization_contact_id);
CREATE INDEX org_con_add_per_org_id_idx ON "fhir".organization_contact_address_periods (organization_id);
CREATE INDEX org_con_add_per_org_con_add_id_idx ON "fhir".organization_contact_address_periods (organization_contact_address_id);
CREATE INDEX org_con_gen_org_id_idx ON "fhir".organization_contact_genders (organization_id);
CREATE INDEX org_con_gen_org_con_id_idx ON "fhir".organization_contact_genders (organization_contact_id);
CREATE INDEX org_con_gen_cod_org_id_idx ON "fhir".organization_contact_gender_codings (organization_id);
CREATE INDEX org_con_gen_cod_org_con_gen_id_idx ON "fhir".organization_contact_gender_codings (organization_contact_gender_id);
CREATE INDEX pra_tex_pra_id_idx ON "fhir".practitioner_texts (practitioner_id);
CREATE INDEX pra_ide_pra_id_idx ON "fhir".practitioner_identifiers (practitioner_id);
CREATE INDEX pra_ide_per_pra_id_idx ON "fhir".practitioner_identifier_periods (practitioner_id);
CREATE INDEX pra_ide_per_pra_ide_id_idx ON "fhir".practitioner_identifier_periods (practitioner_identifier_id);
CREATE INDEX pra_nam_pra_id_idx ON "fhir".practitioner_names (practitioner_id);
CREATE INDEX pra_nam_per_pra_id_idx ON "fhir".practitioner_name_periods (practitioner_id);
CREATE INDEX pra_nam_per_pra_nam_id_idx ON "fhir".practitioner_name_periods (practitioner_name_id);
CREATE INDEX pra_tel_pra_id_idx ON "fhir".practitioner_telecoms (practitioner_id);
CREATE INDEX pra_tel_per_pra_id_idx ON "fhir".practitioner_telecom_periods (practitioner_id);
CREATE INDEX pra_tel_per_pra_tel_id_idx ON "fhir".practitioner_telecom_periods (practitioner_telecom_id);
CREATE INDEX pra_add_pra_id_idx ON "fhir".practitioner_addresses (practitioner_id);
CREATE INDEX pra_add_per_pra_id_idx ON "fhir".practitioner_address_periods (practitioner_id);
CREATE INDEX pra_add_per_pra_add_id_idx ON "fhir".practitioner_address_periods (practitioner_address_id);
CREATE INDEX pra_gen_pra_id_idx ON "fhir".practitioner_genders (practitioner_id);
CREATE INDEX pra_gen_cod_pra_id_idx ON "fhir".practitioner_gender_codings (practitioner_id);
CREATE INDEX pra_gen_cod_pra_gen_id_idx ON "fhir".practitioner_gender_codings (practitioner_gender_id);
CREATE INDEX pra_pho_pra_id_idx ON "fhir".practitioner_photos (practitioner_id);
CREATE INDEX pra_rol_pra_id_idx ON "fhir".practitioner_roles (practitioner_id);
CREATE INDEX pra_rol_cod_pra_id_idx ON "fhir".practitioner_role_codings (practitioner_id);
CREATE INDEX pra_rol_cod_pra_rol_id_idx ON "fhir".practitioner_role_codings (practitioner_role_id);
CREATE INDEX pra_spe_pra_id_idx ON "fhir".practitioner_specialties (practitioner_id);
CREATE INDEX pra_spe_cod_pra_id_idx ON "fhir".practitioner_specialty_codings (practitioner_id);
CREATE INDEX pra_spe_cod_pra_spe_id_idx ON "fhir".practitioner_specialty_codings (practitioner_specialty_id);
CREATE INDEX pra_per_pra_id_idx ON "fhir".practitioner_periods (practitioner_id);
CREATE INDEX pra_qua_pra_id_idx ON "fhir".practitioner_qualifications (practitioner_id);
CREATE INDEX pra_qua_cod_pra_id_idx ON "fhir".practitioner_qualification_codes (practitioner_id);
CREATE INDEX pra_qua_cod_pra_qua_id_idx ON "fhir".practitioner_qualification_codes (practitioner_qualification_id);
CREATE INDEX pra_qua_cod_cod_pra_id_idx ON "fhir".practitioner_qualification_code_codings (practitioner_id);
CREATE INDEX pra_qua_cod_cod_pra_qua_cod_id_idx ON "fhir".practitioner_qualification_code_codings (practitioner_qualification_code_id);
CREATE INDEX pra_qua_per_pra_id_idx ON "fhir".practitioner_qualification_periods (practitioner_id);
CREATE INDEX pra_qua_per_pra_qua_id_idx ON "fhir".practitioner_qualification_periods (practitioner_qualification_id);
CREATE INDEX pra_com_pra_id_idx ON "fhir".practitioner_communications (practitioner_id);
CREATE INDEX pra_com_cod_pra_id_idx ON "fhir".practitioner_communication_codings (practitioner_id);
CREATE INDEX pra_com_cod_pra_com_id_idx ON "fhir".practitioner_communication_codings (practitioner_communication_id);
CREATE INDEX enc_tex_enc_id_idx ON "fhir".encounter_texts (encounter_id);
CREATE INDEX enc_ide_enc_id_idx ON "fhir".encounter_identifiers (encounter_id);
CREATE INDEX enc_ide_per_enc_id_idx ON "fhir".encounter_identifier_periods (encounter_id);
CREATE INDEX enc_ide_per_enc_ide_id_idx ON "fhir".encounter_identifier_periods (encounter_identifier_id);
CREATE INDEX enc_typ_enc_id_idx ON "fhir".encounter_types (encounter_id);
CREATE INDEX enc_typ_cod_enc_id_idx ON "fhir".encounter_type_codings (encounter_id);
CREATE INDEX enc_typ_cod_enc_typ_id_idx ON "fhir".encounter_type_codings (encounter_type_id);
CREATE INDEX enc_par_enc_id_idx ON "fhir".encounter_participants (encounter_id);
CREATE INDEX enc_len_enc_id_idx ON "fhir".encounter_lengths (encounter_id);
CREATE INDEX enc_rea_enc_id_idx ON "fhir".encounter_reasons (encounter_id);
CREATE INDEX enc_rea_cod_enc_id_idx ON "fhir".encounter_reason_codings (encounter_id);
CREATE INDEX enc_rea_cod_enc_rea_id_idx ON "fhir".encounter_reason_codings (encounter_reason_id);
CREATE INDEX enc_pri_enc_id_idx ON "fhir".encounter_priorities (encounter_id);
CREATE INDEX enc_pri_cod_enc_id_idx ON "fhir".encounter_priority_codings (encounter_id);
CREATE INDEX enc_pri_cod_enc_pri_id_idx ON "fhir".encounter_priority_codings (encounter_priority_id);
CREATE INDEX enc_hos_enc_id_idx ON "fhir".encounter_hospitalizations (encounter_id);
CREATE INDEX enc_hos_pre_adm_ide_enc_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifiers (encounter_id);
CREATE INDEX enc_hos_pre_adm_ide_enc_hos_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifiers (encounter_hospitalization_id);
CREATE INDEX enc_hos_pre_adm_ide_per_enc_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifier_periods (encounter_id);
CREATE INDEX enc_hos_pre_adm_ide_per_enc_hos_pre_adm_ide_id_idx ON "fhir".encounter_hospitalization_pre_admission_identifier_periods (encounter_hospitalization_pre_admission_identifier_id);
CREATE INDEX enc_hos_adm_sou_enc_id_idx ON "fhir".encounter_hospitalization_admit_sources (encounter_id);
CREATE INDEX enc_hos_adm_sou_enc_hos_id_idx ON "fhir".encounter_hospitalization_admit_sources (encounter_hospitalization_id);
CREATE INDEX enc_hos_adm_sou_cod_enc_id_idx ON "fhir".encounter_hospitalization_admit_source_codings (encounter_id);
CREATE INDEX enc_hos_adm_sou_cod_enc_hos_adm_sou_id_idx ON "fhir".encounter_hospitalization_admit_source_codings (encounter_hospitalization_admit_source_id);
CREATE INDEX enc_hos_per_enc_id_idx ON "fhir".encounter_hospitalization_periods (encounter_id);
CREATE INDEX enc_hos_per_enc_hos_id_idx ON "fhir".encounter_hospitalization_periods (encounter_hospitalization_id);
CREATE INDEX enc_hos_acc_enc_id_idx ON "fhir".encounter_hospitalization_accomodations (encounter_id);
CREATE INDEX enc_hos_acc_enc_hos_id_idx ON "fhir".encounter_hospitalization_accomodations (encounter_hospitalization_id);
CREATE INDEX enc_hos_acc_per_enc_id_idx ON "fhir".encounter_hospitalization_accomodation_periods (encounter_id);
CREATE INDEX enc_hos_acc_per_enc_hos_acc_id_idx ON "fhir".encounter_hospitalization_accomodation_periods (encounter_hospitalization_accomodation_id);
CREATE INDEX enc_hos_die_enc_id_idx ON "fhir".encounter_hospitalization_diets (encounter_id);
CREATE INDEX enc_hos_die_enc_hos_id_idx ON "fhir".encounter_hospitalization_diets (encounter_hospitalization_id);
CREATE INDEX enc_hos_die_cod_enc_id_idx ON "fhir".encounter_hospitalization_diet_codings (encounter_id);
CREATE INDEX enc_hos_die_cod_enc_hos_die_id_idx ON "fhir".encounter_hospitalization_diet_codings (encounter_hospitalization_diet_id);
CREATE INDEX enc_hos_spe_cou_enc_id_idx ON "fhir".encounter_hospitalization_special_courtesies (encounter_id);
CREATE INDEX enc_hos_spe_cou_enc_hos_id_idx ON "fhir".encounter_hospitalization_special_courtesies (encounter_hospitalization_id);
CREATE INDEX enc_hos_spe_cou_cod_enc_id_idx ON "fhir".encounter_hospitalization_special_courtesy_codings (encounter_id);
CREATE INDEX enc_hos_spe_cou_cod_enc_hos_spe_cou_id_idx ON "fhir".encounter_hospitalization_special_courtesy_codings (encounter_hospitalization_special_courtesy_id);
CREATE INDEX enc_hos_spe_arr_enc_id_idx ON "fhir".encounter_hospitalization_special_arrangements (encounter_id);
CREATE INDEX enc_hos_spe_arr_enc_hos_id_idx ON "fhir".encounter_hospitalization_special_arrangements (encounter_hospitalization_id);
CREATE INDEX enc_hos_spe_arr_cod_enc_id_idx ON "fhir".encounter_hospitalization_special_arrangement_codings (encounter_id);
CREATE INDEX enc_hos_spe_arr_cod_enc_hos_spe_arr_id_idx ON "fhir".encounter_hospitalization_special_arrangement_codings (encounter_hospitalization_special_arrangement_id);
CREATE INDEX enc_hos_dis_dis_enc_id_idx ON "fhir".encounter_hospitalization_discharge_dispositions (encounter_id);
CREATE INDEX enc_hos_dis_dis_enc_hos_id_idx ON "fhir".encounter_hospitalization_discharge_dispositions (encounter_hospitalization_id);
CREATE INDEX enc_hos_dis_dis_cod_enc_id_idx ON "fhir".encounter_hospitalization_discharge_disposition_codings (encounter_id);
CREATE INDEX enc_hos_dis_dis_cod_enc_hos_dis_dis_id_idx ON "fhir".encounter_hospitalization_discharge_disposition_codings (encounter_hospitalization_discharge_disposition_id);
CREATE INDEX enc_loc_enc_id_idx ON "fhir".encounter_locations (encounter_id);
CREATE INDEX enc_loc_per_enc_id_idx ON "fhir".encounter_location_periods (encounter_id);
CREATE INDEX enc_loc_per_enc_loc_id_idx ON "fhir".encounter_location_periods (encounter_location_id);
CREATE VIEW "fhir".view_patients AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.patient_texts t2
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
              from fhir.patient_identifier_periods t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.patient_identifiers t2
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
              from fhir.patient_name_periods t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.family,t2.given,t2.prefix,t2.suffix
          from fhir.patient_names t2
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
              from fhir.patient_telecom_periods t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.system,t2.value,t2.use
          from fhir.patient_telecoms t2
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
              from fhir.patient_gender_codings t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.patient_genders t2
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
              from fhir.patient_address_periods t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
          from fhir.patient_addresses t2
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
              from fhir.patient_marital_status_codings t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.patient_marital_statuses t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as marital_status,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.content_type,t2.language,t2.data,t2.url,t2.size,t2.hash,t2.title
          from fhir.patient_photos t2
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
                  from fhir.patient_contact_relationship_codings t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_relationship_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_contact_relationships t3
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
                  from fhir.patient_contact_name_periods t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_name_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.family,t3.given,t3.prefix,t3.suffix
              from fhir.patient_contact_names t3
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
                  from fhir.patient_contact_telecom_periods t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_telecom_id = t3.id
                ) t4
             ) as period, t3.system,t3.value,t3.use
              from fhir.patient_contact_telecoms t3
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
                  from fhir.patient_contact_address_periods t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_address_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.line,t3.city,t3.state,t3.zip,t3.country
              from fhir.patient_contact_addresses t3
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
                  from fhir.patient_contact_gender_codings t4
                  WHERE t4.patient_id = t1.id AND t4.patient_contact_gender_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_contact_genders t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as gender, hstore_to_json(hstore(ARRAY['reference', t2.organization_reference ,'display',t2.organization_display])) as organization
          from fhir.patient_contacts t2
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
                  from fhir.patient_animal_species_codings t4
                  WHERE t4.patient_id = t1.id AND t4.patient_animal_specy_id = t3.id
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
                  from fhir.patient_animal_breed_codings t4
                  WHERE t4.patient_id = t1.id AND t4.patient_animal_breed_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_animal_breeds t3
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
                  from fhir.patient_animal_gender_status_codings t4
                  WHERE t4.patient_id = t1.id AND t4.patient_animal_gender_status_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.patient_animal_gender_statuses t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as gender_status
          from fhir.patient_animals t2
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
              from fhir.patient_communication_codings t3
              WHERE t3.patient_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.patient_communications t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as communication,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.type, hstore_to_json(hstore(ARRAY['reference', t2.other_reference ,'display',t2.other_display])) as other
          from fhir.patient_links t2
          WHERE t2.patient_id = t1.id
        ) t2
     ) as link, t1.birth_date,t1.deceased_boolean,t1.deceased_date_time,t1.multiple_birth_boolean,t1.multiple_birth_integer,t1.active,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.care_provider_reference ,'display',t1.care_provider_display])) as care_provider,hstore_to_json(hstore(ARRAY['reference', t1.managing_organization_reference ,'display',t1.managing_organization_display])) as managing_organization
  from fhir.patients t1
) t1
;
CREATE VIEW "fhir".view_organizations AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.organization_texts t2
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
              from fhir.organization_identifier_periods t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.organization_identifiers t2
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
              from fhir.organization_type_codings t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.organization_types t2
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
              from fhir.organization_telecom_periods t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as period, t2.system,t2.value,t2.use
          from fhir.organization_telecoms t2
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
              from fhir.organization_address_periods t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
          from fhir.organization_addresses t2
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
                  from fhir.organization_contact_purpose_codings t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_purpose_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.organization_contact_purposes t3
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
                  from fhir.organization_contact_name_periods t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_name_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.family,t3.given,t3.prefix,t3.suffix
              from fhir.organization_contact_names t3
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
                  from fhir.organization_contact_telecom_periods t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_telecom_id = t3.id
                ) t4
             ) as period, t3.system,t3.value,t3.use
              from fhir.organization_contact_telecoms t3
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
                  from fhir.organization_contact_address_periods t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_address_id = t3.id
                ) t4
             ) as period, t3.use,t3.text,t3.line,t3.city,t3.state,t3.zip,t3.country
              from fhir.organization_contact_addresses t3
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
                  from fhir.organization_contact_gender_codings t4
                  WHERE t4.organization_id = t1.id AND t4.organization_contact_gender_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.organization_contact_genders t3
              WHERE t3.organization_id = t1.id
            ) t3
         ) as gender
          from fhir.organization_contacts t2
          WHERE t2.organization_id = t1.id
        ) t2
     ) as contact, t1.name,t1.active,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.part_of_reference ,'display',t1.part_of_display])) as part_of
  from fhir.organizations t1
) t1
;
CREATE VIEW "fhir".view_practitioners AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.practitioner_texts t2
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
              from fhir.practitioner_identifier_periods t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.practitioner_identifiers t2
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
              from fhir.practitioner_name_periods t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.family,t2.given,t2.prefix,t2.suffix
          from fhir.practitioner_names t2
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
              from fhir.practitioner_telecom_periods t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.system,t2.value,t2.use
          from fhir.practitioner_telecoms t2
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
              from fhir.practitioner_address_periods t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
          from fhir.practitioner_addresses t2
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
              from fhir.practitioner_gender_codings t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_genders t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as gender,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.content_type,t2.language,t2.data,t2.url,t2.size,t2.hash,t2.title
          from fhir.practitioner_photos t2
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
              from fhir.practitioner_role_codings t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_roles t2
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
              from fhir.practitioner_specialty_codings t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_specialties t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as specialty,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.start,t2.end
          from fhir.practitioner_periods t2
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
                  from fhir.practitioner_qualification_code_codings t4
                  WHERE t4.practitioner_id = t1.id AND t4.practitioner_qualification_code_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.practitioner_qualification_codes t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as code,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.practitioner_qualification_periods t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as period, hstore_to_json(hstore(ARRAY['reference', t2.issuer_reference ,'display',t2.issuer_display])) as issuer
          from fhir.practitioner_qualifications t2
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
              from fhir.practitioner_communication_codings t3
              WHERE t3.practitioner_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.practitioner_communications t2
          WHERE t2.practitioner_id = t1.id
        ) t2
     ) as communication, t1.birth_date,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.organization_reference ,'display',t1.organization_display])) as organization
  from fhir.practitioners t1
) t1
;
CREATE VIEW "fhir".view_encounters AS select t1.id, row_to_json(t1, true) as json from
(
  select id, '#'||inline_id as inline_id,     ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.status
          from fhir.encounter_texts t2
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
              from fhir.encounter_identifier_periods t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as period, t2.use,t2.label,t2.system,t2.value
          from fhir.encounter_identifiers t2
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
              from fhir.encounter_type_codings t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.encounter_types t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as type,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.type, hstore_to_json(hstore(ARRAY['reference', t2.practitioner_reference ,'display',t2.practitioner_display])) as practitioner
          from fhir.encounter_participants t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as participant,
    ( select
      array_to_json(
        array_agg(row_to_json(t2, true)), true) from
        (
          select     t2.value,t2.comparator,t2.units,t2.system,t2.code
          from fhir.encounter_lengths t2
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
              from fhir.encounter_reason_codings t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.encounter_reasons t2
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
              from fhir.encounter_priority_codings t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as coding, t2.text
          from fhir.encounter_priorities t2
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
                  from fhir.encounter_hospitalization_pre_admission_identifier_periods t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_pre_admission_identifier_id = t3.id
                ) t4
             ) as period, t3.use,t3.label,t3.system,t3.value
              from fhir.encounter_hospitalization_pre_admission_identifiers t3
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
                  from fhir.encounter_hospitalization_admit_source_codings t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_admit_source_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_admit_sources t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as admit_source,
        ( select
          array_to_json(
            array_agg(row_to_json(t3, true)), true) from
            (
              select     t3.start,t3.end
              from fhir.encounter_hospitalization_periods t3
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
                  from fhir.encounter_hospitalization_accomodation_periods t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_accomodation_id = t3.id
                ) t4
             ) as period, hstore_to_json(hstore(ARRAY['reference', t3.bed_reference ,'display',t3.bed_display])) as bed
              from fhir.encounter_hospitalization_accomodations t3
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
                  from fhir.encounter_hospitalization_diet_codings t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_diet_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_diets t3
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
                  from fhir.encounter_hospitalization_special_courtesy_codings t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_special_courtesy_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_special_courtesies t3
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
                  from fhir.encounter_hospitalization_special_arrangement_codings t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_special_arrangement_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_special_arrangements t3
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
                  from fhir.encounter_hospitalization_discharge_disposition_codings t4
                  WHERE t4.encounter_id = t1.id AND t4.encounter_hospitalization_discharge_disposition_id = t3.id
                ) t4
             ) as coding, t3.text
              from fhir.encounter_hospitalization_discharge_dispositions t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as discharge_disposition, t2.re_admission, hstore_to_json(hstore(ARRAY['reference', t2.origin_reference ,'display',t2.origin_display])) as origin,hstore_to_json(hstore(ARRAY['reference', t2.destination_reference ,'display',t2.destination_display])) as destination
          from fhir.encounter_hospitalizations t2
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
              from fhir.encounter_location_periods t3
              WHERE t3.encounter_id = t1.id
            ) t3
         ) as period
          from fhir.encounter_locations t2
          WHERE t2.encounter_id = t1.id
        ) t2
     ) as location, t1.status,t1.class,t1.start,t1.resource_type, hstore_to_json(hstore(ARRAY['reference', t1.subject_reference ,'display',t1.subject_display])) as subject,hstore_to_json(hstore(ARRAY['reference', t1.fulfills_reference ,'display',t1.fulfills_display])) as fulfills,hstore_to_json(hstore(ARRAY['reference', t1.indication_reference ,'display',t1.indication_display])) as indication,hstore_to_json(hstore(ARRAY['reference', t1.service_provider_reference ,'display',t1.service_provider_display])) as service_provider,hstore_to_json(hstore(ARRAY['reference', t1.part_of_reference ,'display',t1.part_of_display])) as part_of
  from fhir.encounters t1
) t1
;