--db:myfhir
--{{{

-- remove last item from array
CREATE OR REPLACE
FUNCTION array_pop(ar varchar[])
  RETURNS varchar[] language plv8 AS $$
  ar.pop()
  return ar;
$$;

CREATE OR REPLACE
FUNCTION column_name(name varchar, type varchar)
  RETURNS varchar language plv8 AS $$
  return name.replace('[x]', '_' + type)
$$;

CREATE OR REPLACE
FUNCTION table_name(path varchar[])
  RETURNS varchar LANGUAGE plpgsql AS $$
  BEGIN
    return underscore(array_to_string(path, '_'));
  END
$$;

CREATE OR REPLACE
FUNCTION column_ddl(path varchar[], pg_type varchar, min varchar, max varchar)
  RETURNS varchar LANGUAGE plpgsql AS $$
  BEGIN
    return ('"' ||
      underscore(path[array_length(path, 1)]) ||
      '" ' ||
      pg_type ||
      case
        when max = '*' then '[]'
        else ''
      end ||
      case
        when min = '1' then ' not null'
        else ''
      end);
  END
$$;


-- expand polimorphic types
DROP VIEW meta.expanded_resource_elements CASCADE;
CREATE
VIEW meta.expanded_resource_elements as (
  SELECT *
  FROM (
    SELECT
      path,
      unnest(type) as type,
      min,
      max
    FROM meta.resource_elements
  ) e
  WHERE type not in ('Extension', 'contained')
);

-- get all elements wich have a children
-- all parent path is coumpound (teorema Bodnarchuka)
DROP VIEW IF EXISTS meta.compound_resource_elements CASCADE;
CREATE
VIEW meta.compound_resource_elements as (
  SELECT DISTINCT
    array_pop(path) as path
  FROM meta.expanded_resource_elements
);

-- Two ways of calculate columns:
-- 1. OR primitive OR enum (we suggest that no enums in resource elements)
-- TODO: check invariant
-- 2. expanded_resource_elements - compound_resource_elements - complex_types - resource_references
DROP VIEW IF EXISTS meta.resource_columns CASCADE;
CREATE
VIEW meta.resource_columns as (
    SELECT
      e.path,
      tt.pg_type,
      column_ddl(e.path, tt.pg_type, e.min::varchar, e.max) as column_ddl
    FROM meta.expanded_resource_elements e
    JOIN meta.type_to_pg_type tt ON tt.type = e.type
);


-- elements recursively expanded with complex datatypes
DROP VIEW IF EXISTS meta.expanded_with_dt_resource_elements CASCADE;
CREATE
VIEW meta.expanded_with_dt_resource_elements as (
    SELECT
      e.path || t.path as path,
      table_name(ARRAY[t.type_name] || t.path) as base_table
    FROM meta.expanded_resource_elements e
    JOIN meta.dt_types t ON t.type_name = e.type AND t.type_name <> 'Resource'
);


-- select all tables will be created
-- for resource, compound element and complex type
DROP VIEW IF EXISTS meta.resource_tables CASCADE;
CREATE
VIEW meta.resource_tables as (
  SELECT
    table_name(path) as table_name,
    case
      when array_length(path, 1) > 1 then 'resource_component'
      else 'resource'
    end as base_table,
    (
      SELECT array_agg(column_ddl)
        FROM meta.resource_columns rc
       WHERE array_pop(rc.path) = e.path
    ) as columns
  FROM meta.compound_resource_elements e
  UNION
  SELECT
    table_name(path) as table_name,
    base_table,
    array[]::varchar[] as columns
  FROM meta.expanded_with_dt_resource_elements
);
---}}}
