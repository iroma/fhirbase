\set medapp `cat $FHIR_HOME/js/medapp.js`
\set schema `cat $FHIR_HOME/js/schema.js`
delete from plv8_modules where modname= 'medapp';
delete from plv8_modules where modname= 'schema';
insert into plv8_modules values ('medapp', true, :'medapp');
insert into plv8_modules values ('schema', true, :'schema');

-- TODO: move to test
do language plv8 $$
  load_module('schema')
  load_module('medapp')
$$;
