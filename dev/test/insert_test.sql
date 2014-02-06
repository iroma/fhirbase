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

--}}}
--{{{

\ir ../sql/load_plv8_modules.sql
\ir ../sql/insert.sql

\set pt_json `cat $FHIR_HOME/test/fixtures/patient.json`

BEGIN;
SELECT plan(2);
select insert_resource(:'pt_json'::json);

SELECT is(count(*)::integer, 1,'insert patient')
FROM fhirr.patient;

SELECT is(family, ARRAY['Bor']::varchar[],'should record name')
FROM fhirr.patient_name
WHERE text = 'Roel';

SELECT
is(_type, 'patient')
FROM fhirr.resource;

SELECT _type, * FROM fhirr.resource_component;
select * from fhirr.patient_name;

SELECT * FROM finish();
ROLLBACK;
--}}}
--{{{
--}}}
--{{{
--}}}
