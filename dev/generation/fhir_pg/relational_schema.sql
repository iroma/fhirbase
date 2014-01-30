--db:myfhir
--{{{
drop schema if exists meta cascade;
create schema meta;

create table meta.datatypes (
  version varchar,
  type varchar,
  kind varchar,
  extension varchar,
  restriction_base varchar,
  documentation text[],
  PRIMARY KEY(type)
);
create table meta.datatype_elements (
  version varchar,
  datatype varchar references meta.datatypes(type),
  name varchar,
  type varchar,
  min_occurs integer,
  max_occurs varchar,
  documentation text,
  PRIMARY KEY(datatype, name)
);

create table meta.datatype_enums (
  version varchar,
  datatype varchar references meta.datatypes(type),
  value varchar,
  documentation text,
  PRIMARY KEY(datatype, value)
);

create table meta.resources (
  version varchar,
  type varchar,
  publish boolean,
  PRIMARY KEY(type)
);

create table meta.resource_elements (
  version varchar,
  path varchar[],
  is_modifier boolean,
  min integer,
  max varchar,
  resource varchar references meta.resources(type),
  synonym varchar[],
  type varchar[],
  short text,
  formal text,
  mapping_target varchar,
  mapping_map varchar,
  PRIMARY KEY(path)
);

create table meta.resource_element_bindings (
  version varchar,
  path varchar[],
  TODO varchar,
  PRIMARY KEY(path)
);
--}}}

--{{{
drop view if exists meta.complex_datatypes cascade;
create view meta.complex_datatypes as (
  select * from meta.datatypes
  where extension is null and kind = 'complexType'
);

drop view if exists meta.primitive_datatypes;
create view meta.primitive_datatypes as (
  select * from meta.datatypes
  where (type || '-primitive') = extension
  OR type = 'xmlIdRef'
);

drop view if exists meta.enums;
create view meta.enums as (
  select replace(datatype, '-list','') as enum, array_agg(value) as options
  from meta.datatype_enums
  group by replace(datatype, '-list','')
);

drop view if exists meta.components;
create view meta.components as (
  select re.path as parent_path, se.*
  from meta.resource_elements re , meta.resource_elements se
  where se.path && re.path
  and array_to_string(se.path,'.') like (array_to_string(re.path,'.') || '.%')
  and array_length(se.path,1) = (array_length(re.path,1) + 1)
  and (se.type <> Array['Extension'::varchar] OR se.type is null)
  and se.path[array_length(se.path, 1)] <> 'contained'
  order by se.path
);

DROP VIEW IF EXISTS meta.datatype_deps;
create view meta.datatype_deps as (
  select cd.type as datatype,
  de.type deps
  from meta.complex_datatypes cd
  left join
  (
    select dd.*
    from meta.datatype_elements dd
    join meta.complex_datatypes cdd on cdd.type = dd.type
  ) de on de.datatype =  cd.type
  where cd.type not in ('Resource', 'BackboneElement', 'Extension', 'Narrative')
group by cd.type, de.type
);


-- meta

drop table meta.type_to_pg_type cascade;
create table meta.type_to_pg_type (
  type varchar,
  pg_type varchar
);

insert into meta.type_to_pg_type (type, pg_type)
VALUES
   ('code', 'varchar'),
   ('dateTime', 'timestamp'),
   ('date_time', 'timestamp'),
   ('string', 'varchar'),
   ('uri', 'varchar'),
   ('datetime', 'timestamp'),
   ('instant', 'timestamp'),
   ('boolean', 'boolean'),
   ('base64_binary', 'bytea'),
   ('integer', 'integer'),
   ('decimal', 'decimal'),
   ('sampled_data_data_type', 'text'),
   ('date', 'date'),
   ('id', 'varchar'),
   ('oid', 'varchar');


create OR replace function underscore(str varchar)
  returns varchar
  language plv8
  as $$
   return str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").replace('.','').toLowerCase();
$$;

create OR replace function column_name(name varchar, type varchar)
  returns varchar
  language plv8
  as $$
  if(name.indexOf('[x]')){
    return name.replace('[x]', '_' + type)
  } else {
    return name;
  }
$$;

DROP VIEW IF EXISTS meta.tables_ddl;
CREATE ViEW meta.tables_ddl as (
with ucomp as ( select *, unnest(c.type) as tp from meta.components c)
select c.path,
underscore(array_to_string(c.path, '_')) as table_name,
underscore(coalesce(c.type[1], 'resource_component')) as parent_table,
c.type,
array(
      select underscore(column_name(path[array_length(path,1)], cm1.tp)) || ' ' || tt.pg_type ||
      case cm1.max
        when '*' then '[]'
        else ''
      end
      as name
      from ucomp cm1
      join meta.primitive_datatypes pd on pd.type = cm1.tp
      join type_to_pg_type tt on tt.type = cm1.tp
      where cm1.parent_path = c.path
) as columns,
array(
    select path[array_length(path,1)] || ' ' || cm1.tp  as name
    from ucomp cm1
    join meta.complex_datatypes pd on pd.type = cm1.tp
    where cm1.parent_path = c.path
) as complex
from meta.resource_elements c
where type is null OR type = Array['Resource'::varchar]
order by c.path
);


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

-- datatypes

drop view if exists meta.dt_tree, meta.dt_raw cascade;

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

drop view if exists meta.dt_tree;
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
    when t.base_name = 'resource_value' then array(
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
  base_name as base_table,
  array_to_string(Array[underscore(type_name)] || path, '_') as table_name,
  columns
  from meta.dt_types
  order by level, type_name, path
);
--}}}
