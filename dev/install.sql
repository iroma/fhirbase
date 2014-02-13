--db:testfhir
--{{{
DROP SCHEMA IF EXISTS meta CASCADE;

\ir sql/extensions.sql
\ir sql/py_init.sql
\ir sql/meta.sql
\ir sql/load_meta.sql
\ir sql/functions.sql
\ir sql/datatypes.sql
\ir sql/schema.sql
\ir sql/generate_schema.sql
\ir sql/views.sql
\ir sql/insert.sql
\ir sql/delete.sql
\ir sql/update.sql

--}}}
