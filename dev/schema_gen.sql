--db:myfhir
--{{{
\set medapp `cat ./js_build/medapp.js`
\set schema `cat ./js_build/schema.js`
delete from plv8_modules where modname= 'medapp';
delete from plv8_modules where modname= 'schema';
insert into plv8_modules values ('medapp', true, :'medapp');
insert into plv8_modules values ('schema', true, :'schema');

do language plv8 $$
  load_module('schema')
  sql.generate_schema('0.12')
$$;

\dt fhirr.*

--}}}

--{{{
  select dd.*
  from meta.datatype_elements dd
  join meta.complex_datatypes cdd on cdd.type = dd.type;
select row_to_json(foo.*) from (
  select de.datatype,
  array_agg(row_to_json(de.*)) attrs
  from meta.complex_datatypes cd
  join meta.datatype_elements de on de.datatype =  cd.type
  where cd.type not in ('Resource', 'BackboneElement', 'Extension', 'Narrative')
  group by datatype
) as foo;

--{{{
drop view dt_deps;
create view dt_deps as (
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

select * from dt_deps;
--}}}
--select * from dt_deps order by datatype;

--select * from dt_deps where deps is null order by deps;
--select * from dt_deps where deps is not null order by deps;

with level1 as (select 1 as level, datatype from dt_deps where deps is null)

with level2 as (
  select min(level) as level, datatype from (
    select 2 as level, datatype from dt_deps where deps not in (
      select datatype from dt_deps where deps not in (select datatype from level1)
    ) UNION (select * from level1)
  ) foo group by datatype
  order by level
)
select * from level2;
;

select min(level) as level, datatype from (
  select 3 as level, datatype from dt_deps where deps not in (
    select datatype from dt_deps where deps not in (select datatype from level2)
  ) UNION (select * from level2)
) foo group by datatype
order by level ;

--}}}
--{{{
WITH RECURSIVE more_types(level1) AS (
  select 1 as level, datatype from dt_deps where deps is null
  UNION
  select min(level) as level, datatype from (
    select 2 as level, datatype from dt_deps where deps not in (
      select datatype from dt_deps where deps not in (select datatype from level1)
    ) UNION (select * from level1)
  ) foo group by datatype
  order by level
)
--}}}
