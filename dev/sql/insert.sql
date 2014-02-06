DROP function if exists insert_resource(json);
create OR replace function insert_resource(res json)
  returns uuid
  language plv8
  as $$
  load_module('persistence');
  return insert_resource(res);
$$;
