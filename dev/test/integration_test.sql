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

BEGIN;
SELECT plan(1);

\timing
select * from meta.resource_tables;

do language plv8 $$
  load_module('schema')
  sql.generate_schema('0.12')
$$;

SELECT * FROM finish();
ROLLBACK;
--}}}
