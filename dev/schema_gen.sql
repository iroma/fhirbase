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
--\dt meta.
--select * from meta.datatypes;
select *
from meta.datatype_ddl
where array_length(columns, 1) is not null;
--}}}
