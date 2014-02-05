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

BEGIN;
SELECT plan(1);

SELECT * FROM meta.dt_raw;

\timing

SELECT * FROM finish();
ROLLBACK;
--}}}
--{{{
select * from meta.resource_elements;

CREATE OR REPLACE
VIEW meta.datatype_unified_elements AS (
  SELECT
    ARRAY[datatype, name] as path,
    type,
    min_occurs as min,
    case
      when max_occurs = 'unbounded'
        then '*'
      else max_occurs
    end as max
  FROM meta.datatype_elements
);

select * from meta.datatype_unified_elements;
--}}}
