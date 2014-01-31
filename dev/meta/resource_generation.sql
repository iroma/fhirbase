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

-- expand polimorphic types
DROP VIEW meta.expanded_resource_elements CASCADE;
CREATE
VIEW meta.expanded_resource_elements as (
  SELECT *
  FROM (
    SELECT
      path,
      unnest(type) as type
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
      (underscore(e.path[array_length(e.path, 1)]) || ' ' || tt.pg_type) as column_ddl
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

-- select first leve children elements by parent_path
-- select tables to be created
CREATE OR REPLACE
VIEW meta.resource_tables as (
  SELECT DISTINCT
    c.resource,
    table_name(c.parent_path)
  FROM meta.components c
  ORDER BY c.resource, table_name
);


table_name (primitive_columns)
table_name_complex_name_(join data) -> multi table

A * resource, table_name,
column:
 -> primitive -> columns
 -> complex  -> tables
result:
A + agg(primitive) -> tables inherited from resource
union all
A + complex + (join) meta.datatypes_dll -> tables inherited from datatype table

--}}}

-- return tables with columns
CREATE OR REPLACE VIEW meta.tables_ddl AS (
SELECT c.path,
underscore(array_to_string(c.path, '_')) as table_name,
underscore(coalesce(c.type[1], 'resource_component')) as parent_table,
c.type,
array(
      SELECT underscore(column_name(path[array_length(path,1)], cm1.ex_type)) || ' ' || tt.pg_type ||
      case cm1.max
        when '*' then '[]'
        else ''
      end
      as name
      from meta.components cm1
      join meta.primitive_datatypes pd on pd.type = cm1.ex_type
      join type_to_pg_type tt on tt.type = cm1.ex_type
      where cm1.parent_path = c.path
) as columns,
array(
    SELECT path[array_length(path,1)] || ' ' || cm1.ex_type  as name
    from meta.components cm1
    join meta.complex_datatypes pd on pd.type = cm1.ex_type
    where cm1.parent_path = c.path
) as complex
from meta.resource_elements c
where c.type is null OR c.type = Array['Resource'::varchar]
order by c.path
);
--}}}
