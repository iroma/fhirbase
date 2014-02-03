--db:myfhir
--{{{
CREATE EXTENSION IF NOT EXISTS pgtap;

\set ECHO
\set QUIET 1
-- Turn off echo and keep things quiet.

-- Format the output for nice TAP.
\pset format unaligned
\pset tuples_only true
\pset pager

-- Revert all changes on failure.
\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP true
\set QUIET 1

-- Load the TAP functions.
-- Plan the tests.
BEGIN;

SELECT plan(2);


-- Run the tests.
SELECT has_table('meta'::name,'datatypes'::name);
SELECT is(
  (select count(*) from meta.datatypes)::integer
  ,23
  ,'datatypes should be loaded'
);

-- FIXME: move to test
select * from meta.datatypes
where
type not in (
  select type from meta.complex_datatypes
  union
  select type from meta.primitive_datatypes
  union
  select type from meta.enum_datatypes
)
and type not like '%-list'
and type not like '%-primitive';
-- Finish the tests and clean UPDATE table SET attr=value.
SELECT * FROM finish();
ROLLBACK;
--}}}
