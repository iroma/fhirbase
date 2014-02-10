\ir 'spec_helper.sql'
drop schema if exists meta cascade;
\ir ../sql/extensions.sql
\ir ../sql/meta.sql
\ir ../sql/load_meta.sql
\ir ../sql/functions.sql
\ir ../sql/datatypes.sql
\ir ../sql/schema.sql
\ir ../sql/generate_schema.sql

\ir ../sql/views.sql

BEGIN;

SELECT plan(2);

INSERT INTO fhir.patient (id, resource_type, birth_date)
       VALUES(uuid_generate_v1(), 'Patient', '12-12-1987');

SELECT is(
       (SELECT COUNT(*) FROM fhir.patient),
       1::bigint,
       'only one patient was inserted');

SELECT is(
       (SELECT (json->'birthDate')::varchar
         FROM fhir.view_patient LIMIT 1),
       '"1987-12-12 00:00:00"'::varchar,
       'receive correct birth_date from patient view');

SELECT * FROM finish();
ROLLBACK;
