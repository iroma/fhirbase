create or replace function fhir.delete_resource(id uuid) returns integer language plpythonu as $$
  res = plpy.execute("DELETE FROM fhir.resource WHERE id = %s" % plpy.quote_literal(id)).nrows()
  return res
$$;
