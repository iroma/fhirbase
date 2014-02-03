CREATE EXTENSION IF NOT EXISTS plv8;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS hstore;

DROP TABLE IF EXISTS plv8_modules CASCADE;
CREATE TABLE plv8_modules(
  modname text primary key,
  load_on_start boolean,
  code text
);

DROP FUNCTION IF EXISTS public.plv8_init();
CREATE OR REPLACE FUNCTION public.plv8_init()
returns void
language plv8
AS $$
  this.load_module = function(modname) {
    var rows = plv8.execute("SELECT code from plv8_modules where modname = $1", [modname]);
    for (var r = 0; r < rows.length; r++) { eval(rows[r].code) }
  };
$$;
