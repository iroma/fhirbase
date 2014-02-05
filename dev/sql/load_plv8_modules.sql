\set shared `cat $FHIR_HOME/js/shared.js`
\set medapp `cat $FHIR_HOME/js/medapp.js`
\set schema `cat $FHIR_HOME/js/schema.js`
\set views `cat $FHIR_HOME/js/views.js`

delete from plv8_modules where modname IN ('shared', 'medapp', 'schema', 'views');

insert into plv8_modules values ('shared', true, :'shared');
insert into plv8_modules values ('medapp', true, :'medapp');
insert into plv8_modules values ('schema', true, :'schema');
insert into plv8_modules values ('views', true, :'views');

-- TODO: move to test
do language plv8 $$
  load_module('schema')
  load_module('medapp')
$$;
