drop schema if exists meta cascade;
\ir meta/schema.sql
\ir meta/load_fhir.sql
\ir meta/plv8.sql
\ir meta/load_plv8_modules.sql
\ir meta/functions.sql
\ir meta/views.sql
\ir meta/resource_generation.sql
do language plv8 $$
  load_module('schema')
  sql.generate_schema('0.12')
$$;
create OR replace function public.insert_resource(json json)
returns void
language plv8
as $$
  load_module('medapp');
  sql.insert_resource(json)
$$;
