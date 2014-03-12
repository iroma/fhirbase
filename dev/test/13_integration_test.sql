\ir '00_spec_helper.sql'

BEGIN;

\ir ../install.sql

SELECT plan(4);

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

SELECT fhir.insert_resource(:'pt_json'::json) as resource_id \gset

SELECT is(count(*)::integer, 1, 'patient was inserted')
       FROM fhir.patient
       WHERE _id = :'resource_id';

SELECT is((((json->'name')->0)->>'text')::varchar, 'Roel', 'patient name is correct')
       FROM fhir.view_patient
       WHERE _id = :'resource_id';

SELECT is((((json->'name')->0)->>'use')::varchar, 'official', 'patient name.use is correctly saved and restored from DB')
       FROM fhir.view_patient
       WHERE _id = :'resource_id';

SELECT ok((SELECT (ARRAY['maritalStatus', 'deceasedDateTime']::varchar[] <@ array_agg(keys.k)::varchar[])
           FROM (
            SELECT json_object_keys(json) k
            FROM fhir.view_patient
            WHERE _id = :'resource_id'
           ) keys), 'json attributes are correctly capitalized');

SELECT json->'contained' FROM fhir.view_patient;

SELECT * FROM finish();
ROLLBACK;
