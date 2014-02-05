create view meta.enums as (
  select replace(datatype, '-list','') as enum, array_agg(value) as options
  from meta.datatype_enums
  group by replace(datatype, '-list','')
);

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

-- datatypes
-- unify datatype interface to make similar with resource elements

create or replace view meta.dt_raw as (
  select
    d.datatype as type_name,
    Array[]::varchar[] as path,
    underscore(d.name) as column_name,
    d.type as column_type,
    -- FIXME: hack schema name hardcoded
    coalesce(coalesce(t.pg_type, case when d.type is not null then ('fhirr."' || d.type || '"') else null end), 'varchar') ||
      case
        when d.max_occurs = 'unbounded' then '[]'
        else ''
      end || case
        when d.min_occurs = '1' then ' not null'
        else ''
      end as pg_type,
    'resource_value'::varchar as base_name
  from meta.datatype_elements d
  left join meta.type_to_pg_type t on t.type = underscore(coalesce(d.type, 'unexisting'))
);

-- recursively convert datatypes graph to collection with path

create or replace view meta.dt_tree as (
  with recursive tree(
    type_name,
    path,
    column_name,
    column_type,
    pg_type,
    base_name
  ) as (
    select r.*
    from meta.dt_raw r
    union
    select t.type_name,
      t.path || Array[t.column_name] as path,
      r.column_name,
      r.column_type,
      r.pg_type,
      r.type_name as base_name
    from meta.dt_raw r
    join tree t on t.column_type = r.type_name
  )
  select t.type_name,
    t.path,
    t.column_name,
    case
      when exists(
        select *
        from meta.dt_raw r
        where r.type_name = t.column_type) then null
      else t.column_type
    end as column_type,
    t.pg_type,
    t.base_name
  from tree t
);

create or replace view meta.dt_tables as (
  select
  t.type_name,
  t.path,
  underscore(t.base_name) as base_name,
  l.level
  from (
    select distinct type_name, path, base_name
    from meta.dt_tree
  ) t
  join (
    select type_name, coalesce(max(array_length(path, 1)), 0) as level
    from meta.dt_tree
    group by type_name
  ) l on l.type_name = t.type_name
);

create or replace view meta.dt_types as (
  select
  t.type_name,
  t.path,
  t.base_name,
  t.level,
  case
    when t.base_name = 'resource_value'
      then array(
        select '"' || c.column_name || '" ' || c.pg_type
        from meta.dt_tree c
        where c.type_name = t.type_name and c.path = t.path and c.column_type is not null
      )
      else Array[]::varchar[]
  end
  as columns
  from meta.dt_tables t
);

create or replace view meta.datatype_ddl as (
  select
  table_name(ARRAY[base_name]) as base_table,
  table_name(Array[underscore(type_name)] || path) as table_name,
  columns
  from meta.dt_types
  order by level, type_name, path
);
