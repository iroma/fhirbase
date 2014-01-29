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
--select distinct(type) from meta.datatype_elements where type is not null;
select ARRAY[datatype, name] as path, type
from meta.datatype_elements
order by path;

WITH RECURSIVE types(datatype, name, type, level) AS (
  select  datatype, name, type, 1 as level
  from meta.datatype_elements
  where datatype not in (
    select distinct(type) from meta.datatype_elements where type is not null
  )
  UNION ALL
  select '','','',0 where true = false
)
SELECT * FROM types;




--}}}
--{{{
DROP table if EXISTS deps;
CREATE TABLE deps (name varchar, dep varchar);
INSERT INTO deps (name, dep)
VALUES
('b', 'a'),
('a', null),
('d', 'c'),
('c', 'b'),
('c', 'a');

select * from deps;
with level1 as ( select * from deps where dep is null)
select * from deps d
join level1 l1
on l1.name = d.dep
;
--}}}
