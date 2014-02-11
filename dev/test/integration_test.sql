--db:myfhir
--{{{
\ir 'spec_helper.sql'
drop schema if exists meta cascade;
\ir ../sql/extensions.sql
\ir ../sql/py_init.sql
\ir ../sql/meta.sql
\ir ../sql/load_meta.sql
\ir ../sql/functions.sql
\ir ../sql/datatypes.sql
\ir ../sql/schema.sql
\ir ../sql/generate_schema.sql

\ir ../sql/views.sql
\ir ../sql/insert.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

BEGIN;
SELECT plan(4);

-- CREATE LANGUAGE plpythonu;

CREATE OR REPLACE
FUNCTION dump_json(a json, fname varchar) RETURNS void LANGUAGE plpythonu AS $$
  import json
  parsed = json.loads(a)
  pretty = json.dumps(parsed, sort_keys=True, indent=2)

  f = open(fname, "w")
  f.write(pretty)
  f.close()
$$;

SELECT fhir.insert_resource(:'pt_json'::json) as resource_id \gset

SELECT is(count(*)::integer, 1, 'patient was inserted')
       FROM fhir.patient
       WHERE id = :'resource_id';

SELECT is((((json->'name')->0)->>'text')::varchar, 'Roel', 'patient name is correct')
       FROM fhir.view_patient
       WHERE id = :'resource_id';

SELECT dump_json(:'pt_json', '/tmp/original.json');
SELECT dump_json(json, '/tmp/result.json') FROM fhir.view_patient WHERE id = :'resource_id';

SELECT is((((json->'name')->0)->>'use')::varchar, 'official', 'patient name.use is correctly saved and restored from DB')
       FROM fhir.view_patient
       WHERE id = :'resource_id';

SELECT is((((json->'maritalStatus')->'coding')->1)->>'code', '36629006', 'json attributes are correctly capitalized')
       FROM fhir.view_patient
       WHERE id = :'resource_id';

SELECT * FROM finish();
ROLLBACK;
--}}}
