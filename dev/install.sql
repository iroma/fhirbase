--db:testfhir
--{{{
drop schema if exists meta cascade;
\ir sql/meta.sql
\ir sql/load_meta.sql
\ir sql/plv8.sql
\ir sql/load_plv8_modules.sql
\ir sql/functions.sql
\ir sql/datatypes.sql
\ir sql/schema.sql

do language plv8 $$
  load_module('schema')
  sql.generate_schema('0.12')
$$;

\ir sql/views.sql
--}}}
