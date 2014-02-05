-- FIXME: may be use underscore
CREATE OR REPLACE
FUNCTION column_name(name varchar, type varchar)
  RETURNS varchar language plpgsql AS $$
  BEGIN
    return replace(name, '[x]', '_' || type);
  END
$$  IMMUTABLE;

CREATE OR REPLACE
FUNCTION column_ddl(path varchar[], pg_type varchar, min varchar, max varchar)
  RETURNS varchar LANGUAGE plpgsql AS $$
  BEGIN
    return ('"' ||
      underscore(array_last(path)) ||
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
$$ IMMUTABLE;


-- expand polimorphic types
CREATE
VIEW meta.expanded_resource_elements as (
  SELECT
    array_pop(path) || ARRAY[column_name(array_last(path), type)] as path,
    type,
    min,
    max
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
CREATE
VIEW meta.compound_resource_elements as (
  SELECT DISTINCT
    array_pop(path) as path
  FROM meta.expanded_resource_elements
  WHERE array_length(path,1) > 1
);

-- Two ways of calculate columns:
-- 1. OR primitive OR enum (we suggest that no enums in resource elements)
-- TODO: check invariant
-- 2. expanded_resource_elements - compound_resource_elements - complex_types - resource_references
CREATE TABLE meta.resource_columns as (
    SELECT
      e.path as path,
      tt.pg_type as pg_type,
      column_ddl(e.path, tt.pg_type, e.min::varchar, e.max) as column_ddl
    FROM meta.expanded_resource_elements e
    JOIN meta.type_to_pg_type tt ON tt.type = e.type
);


-- elements recursively expanded with complex datatypes
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
CREATE
VIEW meta.resource_tables as (
  SELECT
    table_name(path) as table_name,
    case
      when array_length(path, 1) > 1 then 'resource_component'
      else 'resource'
    end as base_table,
    coalesce((
      SELECT array_agg(column_ddl)
        FROM meta.resource_columns rc
       WHERE array_pop(rc.path) = e.path
    ), ARRAY[]::varchar[]) as columns
  FROM meta.compound_resource_elements e
  UNION
  SELECT
    table_name(path) as table_name,
    base_table,
    array[]::varchar[] as columns
  FROM meta.expanded_with_dt_resource_elements
);
