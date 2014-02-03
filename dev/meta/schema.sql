--db:testfhir
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

--create table meta.resources (
--version varchar,
--type varchar,
--publish boolean,
--PRIMARY KEY(type)
--);

create table meta.resource_elements (
  version varchar,
  path varchar[],
  min varchar,
  max varchar,
  type varchar[],
  --is_modifier boolean,
  --resource varchar references meta.resources(type),
  --synonym varchar[],
  --short text,
  --formal text,
  --mapping_target varchar,
  --mapping_map varchar,
  PRIMARY KEY(path)
);

--create table meta.resource_element_bindings (
  --  version varchar,
  --  path varchar[],
  --  TODO varchar,
  --  PRIMARY KEY(path)
  --);

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
--}}}
