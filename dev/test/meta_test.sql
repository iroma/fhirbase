--db:testfhir
--{{{
\ir 'spec_helper.sql'
drop schema if exists meta cascade;
\ir ../sql/meta.sql

BEGIN;
SELECT plan(5);

SELECT has_table('meta','datatypes', 'has table');
SELECT has_table('meta','datatype_elements', 'has table');
SELECT has_table('meta','datatype_enums', 'has table');
SELECT has_table('meta','resource_elements', 'has table');
SELECT has_table('meta','type_to_pg_type', 'has table');
SELECT has_table('meta','word_aliases', 'has table');


SELECT * FROM finish();
ROLLBACK;
--}}}
