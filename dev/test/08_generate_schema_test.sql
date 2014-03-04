\ir '00_spec_helper.sql'

BEGIN;

\ir ../sql/01_extensions.sql
\ir ../sql/02_py_init.sql
\ir ../sql/03_meta.sql
\ir ../sql/04_load_meta.sql
\ir ../sql/05_functions.sql
\ir ../sql/06_datatypes.sql
\ir ../sql/07_schema.sql
\ir ../sql/08_generate_schema.sql

SELECT plan(0);

-- TODO: write test

ROLLBACK;
