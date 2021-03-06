\ir '00_spec_helper.sql'

BEGIN;

\ir ../sql/01_extensions.sql
\ir ../sql/03_meta.sql
\ir ../sql/04_load_meta.sql
\ir ../sql/05_functions.sql
\ir ../sql/06_datatypes.sql
\ir ../sql/07_schema.sql
\ir ../sql/08_generate_schema.sql
\ir ../sql/09_views.sql
\ir ../sql/10__insert_helpers.sql
\ir ../sql/10_insert.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

SELECT plan(8);

select fhir.insert_resource(:'pt_json'::json) as resource_id \gset

\echo :'resource_id';

SELECT is(count(*)::integer, 1, 'insert patient')
       FROM fhir.patient;

SELECT is(
       (SELECT family FROM fhir.patient_name
         WHERE text = 'Roel'
         AND resource_id = :'resource_id'),
       ARRAY['Bor']::varchar[],
       'should record name');

SELECT is(_type, 'patient')
       FROM fhir.resource
       WHERE _id = :'resource_id';

SELECT is(count(*)::int, 2)
       FROM fhir.patient_gender_cd
       WHERE resource_id = :'resource_id';

SELECT is_empty(
  'SELECT *
  FROM fhir.resource_component
  WHERE _unknown_attributes IS NOT NULL',
  'should not contain any _unknown_attributes'
);

SELECT * FROM fhir.organization;

SELECT is((SELECT array_agg(name) FROM fhir.organization
       WHERE container_id = :'resource_id'),
       ARRAY['ACME', 'Foobar']::varchar[],
       'contained resource was correctly saved');

SELECT is((SELECT array_agg(id) FROM fhir.organization
       WHERE container_id = :'resource_id'),
       ARRAY['#org1', '#org2']::varchar[],
       'id should be correct');

SELECT is((SELECT array_agg(ot.value) FROM fhir.organization_telecom ot
       JOIN fhir.organization o ON o._id = ot.parent_id
       WHERE o.container_id = :'resource_id'),
       ARRAY['+31612234322', '+31612234000']::varchar[],
       'contained resource was correctly saved');

SELECT * FROM finish();
ROLLBACK;
