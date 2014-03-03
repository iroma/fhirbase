\ir '00_spec_helper.sql'
\ir ../install.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`
\set new_pt_json `cat $FHIRBASE_HOME/test/fixtures/updated_patient.json`

BEGIN;
SELECT plan(4);

SELECT fhir.insert_resource(:'pt_json'::json) AS resource_id \gset

SELECT is(COUNT(*)::integer, 1, 'patient was inserted')
       FROM fhir.view_patient WHERE id = :'resource_id';

SELECT is(
       (SELECT text::varchar
       FROM fhir.patient_name WHERE resource_id = :'resource_id'),
       'Roel'::varchar,
       'patient data was placed in correct tables');

SELECT fhir.update_resource(:'resource_id', :'new_pt_json'::json);

SELECT is(
       (SELECT text::varchar
       FROM fhir.patient_name WHERE resource_id = :'resource_id'),
       'Gavrila'::varchar,
       'patient data was correctly updated');

-- test if error was thrown when update_resource is called with
-- unknown resource ID
SELECT uuid_generate_v4() AS random_uuid \gset
PREPARE incorrect_update_resource_call AS SELECT fhir.update_resource(:'random_uuid', :'pt_json'::json);
SELECT throws_ok(
  'incorrect_update_resource_call',
  'Resource with id ' || :'random_uuid'::varchar || ' not found'
);

SELECT * FROM finish();
ROLLBACK;
