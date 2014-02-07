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
  sql.generate_schema('fhir', '0.12')
$$;

--}}}
--{{{

\ir ../sql/load_plv8_modules.sql
\ir ../sql/insert.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

BEGIN;
SELECT plan(5);

\timing
select insert_resource(:'pt_json'::json) as resource_id \gset

SELECT :'resource_id';

SELECT is(count(*)::integer, 1, 'insert patient')
       FROM fhir.patient;

SELECT is(family, ARRAY['Bor']::varchar[], 'should record name')
       FROM fhir.patient_name
       WHERE text = 'Roel'
       AND resource_id = :'resource_id';

SELECT is(_type, 'patient')
       FROM fhir.resource
       WHERE id = :'resource_id';

SELECT is(count(*)::int, 2)
       FROM fhir.patient_gender_cd
       WHERE resource_id = :'resource_id';

SELECT is_empty(
  'SELECT *
  FROM fhir.resource_component
  WHERE _unknown_attributes IS NOT NULL',
  'should not contain any _unknown_attributes'
);

SELECT * FROM finish();
ROLLBACK;
--}}}
