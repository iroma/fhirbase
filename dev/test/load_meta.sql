--db:testfhir
--{{{
\ir 'spec_helper.sql'
drop schema if exists meta cascade;
\ir ../sql/meta.sql
\ir ../sql/load_meta.sql

BEGIN;
SELECT plan(9);

SELECT is(max,'*','should be multiple')
 FROM meta.resource_elements
WHERE
 path[1] = 'Patient'
 AND path[2] = 'name';

SELECT * FROM finish();
ROLLBACK;
--}}}
