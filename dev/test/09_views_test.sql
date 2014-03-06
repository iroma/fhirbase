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

SELECT plan(8);

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

SELECT fhir.insert_resource(:'pt_json'::json) AS resource_id \gset

SELECT is(
       (SELECT COUNT(*) FROM fhir.patient),
       1::bigint,
       'only one patient was inserted');

SELECT is(
       (SELECT (json->>'resourceType')::varchar
         FROM fhir.view_patient LIMIT 1),
       'Patient'::varchar,
       'receive correct resourceType from patient view');

SELECT is(
       (SELECT (json->>'birthDate')::varchar
         FROM fhir.view_patient LIMIT 1),
       '1960-03-13 00:00:00'::varchar,
       'receive correct birth_date from patient view');

SELECT is_empty('SELECT id FROM fhir.view_organization
                        WHERE (json->>''name'')::varchar = ''ACME''::varchar',
                'contained resource is not available as regular resource');

SELECT is(
       (SELECT (json->'contained'->0->>'name')::varchar
         FROM fhir.view_patient LIMIT 1),
       'ACME'::varchar,
       'receive correct name for first contained resource');

SELECT is(
       (SELECT (json->'contained'->0->>'id')::varchar
         FROM fhir.view_patient LIMIT 1),
       '#org1'::varchar,
       'receive correct id for first contained resource');

SELECT is(
       (SELECT (json->'contained'->1->>'name')::varchar
         FROM fhir.view_patient LIMIT 1),
       'Foobar'::varchar,
       'receive correct name for second contained resource');

SELECT is(
       (SELECT (json->'contained'->1->>'id')::varchar
         FROM fhir.view_patient LIMIT 1),
       '#org2'::varchar,
       'receive correct id for first contained resource');


SELECT * FROM finish();
ROLLBACK;
