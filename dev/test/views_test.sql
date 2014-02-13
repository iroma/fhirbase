\ir 'spec_helper.sql'
\ir ../install.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

BEGIN;

SELECT plan(3);

SELECT fhir.insert_resource(:'pt_json'::json) AS resource_id \gset

SELECT is(
       (SELECT COUNT(*) FROM fhir.patient),
       1::bigint,
       'only one patient was inserted');

SELECT is(
       (SELECT (json->'birthDate')::varchar
         FROM fhir.view_patient LIMIT 1),
       '"1960-03-13 00:00:00"'::varchar,
       'receive correct birth_date from patient view');

SELECT is_empty('SELECT id FROM fhir.view_organization
                        WHERE (json->>''name'')::varchar = ''ACME''::varchar',
                'contained resource is not available as regular resource');

SELECT * FROM fhir.patient;

SELECT * FROM finish();
ROLLBACK;
