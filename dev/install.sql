--db:testfhir
--{{{
drop schema if exists meta cascade;
\ir sql/extensions.sql
\ir sql/meta.sql
\ir sql/load_meta.sql
\ir sql/functions.sql
\ir sql/datatypes.sql
\ir sql/schema.sql
\ir sql/generate_schema.sql
\ir sql/views.sql
--}}}
