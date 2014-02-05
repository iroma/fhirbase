DROP function if exists insert_resource(json);
create OR replace function insert_resource(res json)
  returns varchar
  language plv8
  as $$
  load_module('medapp');
  return sql.insert_resource(res);
$$;
