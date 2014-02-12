--db:testfhir
--{{{
\ir 'spec_helper.sql'
\ir ../sql/extensions.sql
\ir ../sql/py_init.sql
\ir ../sql/meta.sql
\ir ../sql/load_meta.sql
\ir ../sql/functions.sql
BEGIN;
SELECT plan(7);

SELECT is(
  (SELECT array_last(ARRAY['a','b','c'])),
  'c',
  'array_last'
);

SELECT is(
  (SELECT array_pop(ARRAY['a','b','c'])),
  ARRAY['a','b']::varchar[],
  'array_pop'
);

SELECT is(
  (SELECT table_name(ARRAY['a','b','c']::varchar[])),
  'a_b_c',
  'table_name'
);

SELECT is(
  (SELECT table_name(ARRAY['abay','baran','cidr']::varchar[])),
  'abay_baran_cidr',
  'table_name'
);

SELECT is(
  (SELECT table_name(ARRAY['schedule.repeat']::varchar[])),
  'schedulerepeat',
  'table_name'
);

SELECT is(
  (SELECT table_name(ARRAY['xang','abay','baran','cidr']::varchar[])),
  'xang_abay_baran_cidr',
  'table_name'
);

SELECT is(
  merge_json('{"a": 42, "b": 12}'::json, '{"c": 55}'::json)::varchar,
  '{"a": 42, "c": 55, "b": 12}'::json::varchar,
  'merge_json'
);

SELECT * FROM finish();
ROLLBACK;
--}}}
