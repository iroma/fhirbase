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
--}}}

--{{{
drop view if exists meta.complex_datatypes;
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

drop view if exists meta.enum_datatypes;
create view meta.enum_datatypes as (
  select * from meta.datatypes
  where (type || '-list') = extension
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
and type not like '%-primitive'
--}}}
