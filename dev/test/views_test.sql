--db:myfhir
--{{{
\ir 'spec_helper.sql'
drop schema if exists meta cascade;
\ir ../sql/meta.sql
\ir ../sql/load_meta.sql
\ir ../sql/plv8.sql
\ir ../sql/load_plv8_modules.sql
\ir ../sql/functions.sql
\ir ../sql/datatypes.sql
\ir ../sql/schema.sql
do language plv8 $$
  load_module('schema')
  sql.generate_schema('0.12')
$$;

\ir ../sql/views.sql

--}}}
--{{{
BEGIN;


SELECT plan(2);

INSERT INTO fhirr.patient (id, resource_type, birth_date)
       VALUES(uuid_generate_v1(), 'Patient', '12-12-1987');

SELECT is(
       (SELECT COUNT(*) FROM fhirr.patient),
       1::bigint,
       'only one patient inserted');

SELECT is(
       (SELECT (json->'birth_date')::varchar
         FROM fhirr.view_patient LIMIT 1),
       '"1987-12-12 00:00:00"'::varchar,
       'receive correct birth_date from patient view');

SELECT * FROM finish();
ROLLBACK;

--}}}

