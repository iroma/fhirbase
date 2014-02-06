create view meta.enums as (
  select replace(datatype, '-list','') as enum, array_agg(value) as options
  from meta.datatype_enums
  group by replace(datatype, '-list','')
);

CREATE VIEW meta.primitive_types as (
  SELECT type, pg_type
  FROM meta.type_to_pg_type
  UNION
  SELECT enum, 'fhirr."' || enum  || '"'-- HACK
  FROM meta.enums
);

CREATE OR REPLACE
VIEW meta._datatype_unified_elements AS (
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
  where datatype <> 'Resource'
);

create or replace
view meta.datatype_unified_elements as (
  with recursive tree(
    path, type, min, max
  ) as (
    select r.* from meta._datatype_unified_elements r
    union
    select
      t.path || ARRAY[array_last(r.path)] as path,
      r.type as type,
      t.min as min,
      t.max as max
    from meta._datatype_unified_elements r
    join tree t on t.type = r.path[1]
  )
  select * from tree t limit 1000
);

CREATE VIEW meta.unified_complex_datatype AS (
  select
    ue.path as path,
    coalesce(tp.type, ue.path[1]) as type
    from (
      select array_pop(path) as path
      from meta.datatype_unified_elements
      group by array_pop(path)
    ) ue
  LEFT JOIN meta.datatype_unified_elements tp
  on tp.path = ue.path
);

CREATE VIEW meta.unified_datatype_columns AS (
  SELECT dt.*,
    pt.pg_type as pg_type,
    column_ddl(array_last(dt.path), pt.pg_type, dt.min, dt.max) as column_ddl
  FROM  meta.datatype_unified_elements dt
  JOIN meta.primitive_types pt ON underscore(pt.type) = underscore(dt.type)
  where array_length(dt.path,1) = 2
);

CREATE OR REPLACE
VIEW meta.datatype_tables AS (
  SELECT
    table_name(path) as table_name,
    case
    when array_length(path, 1) = 1 then 'resource_component'
    else table_name(ARRAY[type])
    end as base_table,
    (SELECT coalesce(array_agg(column_ddl), ARRAY[]::varchar[])
      FROM meta.unified_datatype_columns cls
      WHERE array_pop(cls.path) = cd.path
    ) as columns,
    *
  FROM  meta.unified_complex_datatype cd
  order by array_length(cd.path,1), table_name
);

