\set persistence `cat $FHIR_HOME/js/persistence.js`
\set schema `cat $FHIR_HOME/js/schema.js`

delete from plv8_modules where modname IN ('persistence', 'schema', 'views');

insert into plv8_modules values ('persistence', true, :'persistence');
insert into plv8_modules values ('schema', true, :'schema');

-- TODO: move to test
do language plv8 $$
  load_module('schema')
  load_module('persistence')
$$;
