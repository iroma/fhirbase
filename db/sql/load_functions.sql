--db:test
--{{{
--CREATE EXTENSION IF NOT EXISTS plv8;
--CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
drop table if exists plv8_modules;

create table plv8_modules(modname text primary key, load_on_start boolean, code text);

\set medapp `cat ../js/medapp.js`
insert into plv8_modules values ('medapp', true, :'medapp');

drop function  public.plv8_init();
create OR replace function public.plv8_init()
  returns void
  language plv8
  as $$
  this.load_module = function(modname) {
    var rows = plv8.execute("SELECT code from plv8_modules where modname = $1", [modname]);
    for (var r = 0; r < rows.length; r++) {
      eval(rows[r].code)
    }
  };
$$;

create OR replace function public.insert_resource(json json)
  returns void
  language plv8
  as $$
  load_module('medapp');
  sql.insert_resource(json)
$$;

\set json `cat ./pt1.json`

select insert_resource(:'json');

--}}}

--{{{
do language plv8 $$
  load_module('medapp')
  u.log(str.underscore("MaxBodnarchuk"))
  var columns = [{column_name: 'a'}]
  var attrs = {a: 1, b: 2}
  u.log(sql.fields_to_insert(columns, attrs))
$$;
  select * from plv8_modules;
--}}}
