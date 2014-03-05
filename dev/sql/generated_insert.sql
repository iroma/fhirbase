--db: fhir_build
--{{{
\set pt_json `cat ../test/fixtures/patient.json`

 WITH patient AS ( SELECT uuid_generate_v4() as uuid
         ,ARRAY['patient'] as path
         ,null as parent_id
         ,:'pt_json'::json as value
       ),
 patient_address AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'address') as path,
         p.uuid as parent_id,
         ((p.value::json)->'address') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_address_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_address p WHERE p.value IS NOT NULL
 ),
 patient_animal AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'animal') as path,
         p.uuid as parent_id,
         ((p.value::json)->'animal') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_animal_breed AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'breed') as path,
         p.uuid as parent_id,
         ((p.value::json)->'breed') as value
  FROM patient_animal p WHERE p.value IS NOT NULL
 ),
 patient_animal_breed_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_animal_breed p WHERE p.value IS NOT NULL
 ),
 patient_animal_breed_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_animal_breed_cd p WHERE p.value IS NOT NULL
 ),
 patient_animal_gender_status AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'genderStatus') as path,
         p.uuid as parent_id,
         ((p.value::json)->'genderStatus') as value
  FROM patient_animal p WHERE p.value IS NOT NULL
 ),
 patient_animal_gender_status_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_animal_gender_status p WHERE p.value IS NOT NULL
 ),
 patient_animal_gender_status_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_animal_gender_status_cd p WHERE p.value IS NOT NULL
 ),
 patient_animal_species AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'species') as path,
         p.uuid as parent_id,
         ((p.value::json)->'species') as value
  FROM patient_animal p WHERE p.value IS NOT NULL
 ),
 patient_animal_species_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_animal_species p WHERE p.value IS NOT NULL
 ),
 patient_animal_species_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_animal_species_cd p WHERE p.value IS NOT NULL
 ),
 patient_care_provider AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'careProvider') as path,
         p.uuid as parent_id,
         ((p.value::json)->'careProvider') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_communication AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'communication') as path,
         p.uuid as parent_id,
         ((p.value::json)->'communication') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_communication_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_communication p WHERE p.value IS NOT NULL
 ),
 patient_communication_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_communication_cd p WHERE p.value IS NOT NULL
 ),
 patient_contact AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'contact') as path,
         p.uuid as parent_id,
         json_array_elements((p.value::json)->'contact') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_contact_address AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'address') as path,
         p.uuid as parent_id,
         ((p.value::json)->'address') as value
  FROM patient_contact p WHERE p.value IS NOT NULL
 ),
 patient_contact_address_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_contact_address p WHERE p.value IS NOT NULL
 ),
 patient_contact_gender AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'gender') as path,
         p.uuid as parent_id,
         ((p.value::json)->'gender') as value
  FROM patient_contact p WHERE p.value IS NOT NULL
 ),
 patient_contact_gender_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_contact_gender p WHERE p.value IS NOT NULL
 ),
 patient_contact_gender_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_contact_gender_cd p WHERE p.value IS NOT NULL
 ),
 patient_contact_name AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'name') as path,
         p.uuid as parent_id,
         ((p.value::json)->'name') as value
  FROM patient_contact p WHERE p.value IS NOT NULL
 ),
 patient_contact_name_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_contact_name p WHERE p.value IS NOT NULL
 ),
 patient_contact_organization AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'organization') as path,
         p.uuid as parent_id,
         ((p.value::json)->'organization') as value
  FROM patient_contact p WHERE p.value IS NOT NULL
 ),
 patient_contact_relationship AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'relationship') as path,
         p.uuid as parent_id,
         ((p.value::json)->'relationship') as value
  FROM patient_contact p WHERE p.value IS NOT NULL
 ),
 patient_contact_relationship_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_contact_relationship p WHERE p.value IS NOT NULL
 ),
 patient_contact_relationship_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_contact_relationship_cd p WHERE p.value IS NOT NULL
 ),
 patient_contact_telecom AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'telecom') as path,
         p.uuid as parent_id,
         ((p.value::json)->'telecom') as value
  FROM patient_contact p WHERE p.value IS NOT NULL
 ),
 patient_contact_telecom_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_contact_telecom p WHERE p.value IS NOT NULL
 ),
 patient_gender AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'gender') as path,
         p.uuid as parent_id,
         ((p.value::json)->'gender') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_gender_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_gender p WHERE p.value IS NOT NULL
 ),
 patient_gender_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_gender_cd p WHERE p.value IS NOT NULL
 ),
 patient_idn AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'identifier') as path,
         p.uuid as parent_id,
         ((p.value::json)->'identifier') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_idn_assigner AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'assigner') as path,
         p.uuid as parent_id,
         ((p.value::json)->'assigner') as value
  FROM patient_idn p WHERE p.value IS NOT NULL
 ),
 patient_idn_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_idn p WHERE p.value IS NOT NULL
 ),
 patient_link AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'link') as path,
         p.uuid as parent_id,
         json_array_elements((p.value::json)->'link') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_link_other AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'other') as path,
         p.uuid as parent_id,
         ((p.value::json)->'other') as value
  FROM patient_link p WHERE p.value IS NOT NULL
 ),
 patient_managing_organization AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'managingOrganization') as path,
         p.uuid as parent_id,
         ((p.value::json)->'managingOrganization') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_marital_status AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'maritalStatus') as path,
         p.uuid as parent_id,
         ((p.value::json)->'maritalStatus') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_marital_status_cd AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'coding') as path,
         p.uuid as parent_id,
         ((p.value::json)->'coding') as value
  FROM patient_marital_status p WHERE p.value IS NOT NULL
 ),
 patient_marital_status_cd_vs AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'valueSet') as path,
         p.uuid as parent_id,
         ((p.value::json)->'valueSet') as value
  FROM patient_marital_status_cd p WHERE p.value IS NOT NULL
 ),
 patient_name AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'name') as path,
         p.uuid as parent_id,
         ((p.value::json)->'name') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_name_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_name p WHERE p.value IS NOT NULL
 ),
 patient_photo AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'photo') as path,
         p.uuid as parent_id,
         ((p.value::json)->'photo') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_telecom AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'telecom') as path,
         p.uuid as parent_id,
         ((p.value::json)->'telecom') as value
  FROM patient p WHERE p.value IS NOT NULL
 ),
 patient_telecom_period AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'period') as path,
         p.uuid as parent_id,
         ((p.value::json)->'period') as value
  FROM patient_telecom p WHERE p.value IS NOT NULL
 ),
 patient_text AS (
         SELECT uuid_generate_v4() as uuid,
         array_append(p.path, 'text') as path,
         p.uuid as parent_id,
         ((p.value::json)->'text') as value
  FROM patient p WHERE p.value IS NOT NULL
 )
 SELECT * FROM patient_address
 UNION ALL
 SELECT * FROM patient_address_period
 UNION ALL
 SELECT * FROM patient_animal
 UNION ALL
 SELECT * FROM patient_animal_breed
 UNION ALL
 SELECT * FROM patient_animal_breed_cd
 UNION ALL
 SELECT * FROM patient_animal_breed_cd_vs
 UNION ALL
 SELECT * FROM patient_animal_gender_status
 UNION ALL
 SELECT * FROM patient_animal_gender_status_cd
 UNION ALL
 SELECT * FROM patient_animal_gender_status_cd_vs
 UNION ALL
 SELECT * FROM patient_animal_species
 UNION ALL
 SELECT * FROM patient_animal_species_cd
 UNION ALL
 SELECT * FROM patient_animal_species_cd_vs
 UNION ALL
 SELECT * FROM patient_care_provider
 UNION ALL
 SELECT * FROM patient_communication
 UNION ALL
 SELECT * FROM patient_communication_cd
 UNION ALL
 SELECT * FROM patient_communication_cd_vs
 UNION ALL
 SELECT * FROM patient_contact
 UNION ALL
 SELECT * FROM patient_contact_address
 UNION ALL
 SELECT * FROM patient_contact_address_period
 UNION ALL
 SELECT * FROM patient_contact_gender
 UNION ALL
 SELECT * FROM patient_contact_gender_cd
 UNION ALL
 SELECT * FROM patient_contact_gender_cd_vs
 UNION ALL
 SELECT * FROM patient_contact_name
 UNION ALL
 SELECT * FROM patient_contact_name_period
 UNION ALL
 SELECT * FROM patient_contact_organization
 UNION ALL
 SELECT * FROM patient_contact_relationship
 UNION ALL
 SELECT * FROM patient_contact_relationship_cd
 UNION ALL
 SELECT * FROM patient_contact_relationship_cd_vs
 UNION ALL
 SELECT * FROM patient_contact_telecom
 UNION ALL
 SELECT * FROM patient_contact_telecom_period
 UNION ALL
 SELECT * FROM patient_gender
 UNION ALL
 SELECT * FROM patient_gender_cd
 UNION ALL
 SELECT * FROM patient_gender_cd_vs
 UNION ALL
 SELECT * FROM patient_idn
 UNION ALL
 SELECT * FROM patient_idn_assigner
 UNION ALL
 SELECT * FROM patient_idn_period
 UNION ALL
 SELECT * FROM patient_link
 UNION ALL
 SELECT * FROM patient_link_other
 UNION ALL
 SELECT * FROM patient_managing_organization
 UNION ALL
 SELECT * FROM patient_marital_status
 UNION ALL
 SELECT * FROM patient_marital_status_cd
 UNION ALL
 SELECT * FROM patient_marital_status_cd_vs
 UNION ALL
 SELECT * FROM patient_name
 UNION ALL
 SELECT * FROM patient_name_period
 UNION ALL
 SELECT * FROM patient_photo
 UNION ALL
 SELECT * FROM patient_telecom
 UNION ALL
 SELECT * FROM patient_telecom_period
 UNION ALL
 SELECT * FROM patient_text
--}}}
