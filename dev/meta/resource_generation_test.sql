--db:myfhir
--{{{
CREATE EXTENSION IF NOT EXISTS pgtap;

\set ECHO
\set QUIET 1
-- Turn off echo and keep things quiet.

-- Format the output for nice TAP.
\pset format unaligned
--\pset tuples_only true
\pset pager

-- Revert all changes on failure.
\set ON_ERROR_ROLLBACK 1
\set ON_ERROR_STOP true
\set QUIET 1

-- Load the TAP functions.
-- Plan the tests.
BEGIN;

SELECT plan(6);

-- test components

SELECT is(
  (SELECT table_name(ARRAY['a','b','c']::varchar[])),
  'a_b_c',
  'table_name'
);


SELECT is (
  (
    SELECT array_agg(type)
    FROM meta.expanded_resource_elements
    WHERE path[1] = 'Patient'
    and path[2] = 'deceased[x]'
  ),
  ARRAY['boolean','dateTime']::varchar[],
  'should expand polimorphic'
);

SELECT is (
  (
    select array_agg(path[array_length(path,1)])
    from meta.compound_resource_elements
    where path[1] = 'Encounter'
  ),
  ARRAY['Encounter', 'hospitalization','accomodation','location','participant' ]::varchar[],
  'should select only compaund elements'
);

SELECT is(
(
  SELECT count(*)::integer
  FROM meta.expanded_resource_elements e
  JOIN meta.enums en ON en.enum = e.type
 ),
 0, 'no enums in resource elements'
);

SELECT is(
  (
    SELECT array_agg(attr) FROM (
      SELECT
        path[2] as attr
      FROM meta.resource_columns
      WHERE path[1] = 'Encounter'
        AND array_length(path,1) = 2
      ORDER BY attr
    ) pp
  ),
  ARRAY['class','start','status']::varchar[],
  'only 3 columns in encounter'
);

SELECT is(column_ddl, '"comment" varchar[]', 'should be array')
FROM meta.resource_columns
WHERE
  path[1] = 'Specimen'
  AND path[2] = 'collection'
  AND path[3] = 'comment';

SELECT is(column_ddl, '"note" varchar not null', 'should be not null')
FROM meta.resource_columns
WHERE
  path[1] = 'Alert'
  AND path[2] = 'note';

SELECT is(
  (
    SELECT base_table
    FROM meta.expanded_with_dt_resource_elements
    where path[1] = 'Encounter'
    AND path[3] = 'accomodation'
    order by path
  ),
  'period',
  'only 3 columns in encounter'
);

SELECT is(
  (
    SELECT count(*)::integer
    FROM meta.resource_tables
    where table_name in ('encounter',
      'encounter_hospitalization',
      'encounter_hospitalization_accomodation',
      'encounter_identifier_period')
  ),
  4,
  'check some tables in encounter'
);

SELECT * FROM finish();
ROLLBACK;
--}}}

select table_name, base_name, columns
from (
SELECT
  c.path,
  underscore(array_to_string(c.path, '_')) as table_name,
  'resource' as base_name,
  (
    select
      array_agg(ee.path[array_length(ee.path, 1)] || ' ' || ee.type)
    from meta.expanded_resource_elements ee
    left join meta.dt_raw tt on tt.type_name = ee.type
    where tt.type_name is null and array_pop(ee.path) = c.path
  ) as columns
FROM meta.compound_resource_elements c
UNION ALL
SELECT
  e.path,
  underscore(array_to_string(e.path || t.path, '_')) as table_name,
  underscore(array_to_string(array[t.type_name] || t.path, '_')) as base_name,
  array[]::varchar[] as columns
FROM meta.compound_resource_elements c
JOIN meta.expanded_resource_elements e on array_pop(e.path) = c.path
JOIN meta.dt_types t on t.type_name = e.type
) x
where path[1] = 'Encounter'
order by table_name;



-- SELECT * from meta.resource_tables;


SELECT * FROM finish();
ROLLBACK;
--}}}
