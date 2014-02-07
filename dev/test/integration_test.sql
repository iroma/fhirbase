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

\ir ../sql/views.sql
\ir ../sql/insert.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

BEGIN;
SELECT plan(2);

SELECT insert_resource(:'pt_json'::json) as resource_id \gset

SELECT is(count(*)::integer, 1, 'patient was inserted')
       FROM fhir.patient
       WHERE id = :'resource_id';

SELECT is((((json->'name')->0)->>'text')::varchar, 'Roel', 'patient name is correct')
       FROM fhir.view_patient
       WHERE id = :'resource_id';

SELECT * FROM finish();
ROLLBACK;
--}}}
