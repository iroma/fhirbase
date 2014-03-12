CREATE OR REPLACE FUNCTION fhir.update_resource(id uuid, resource_data json)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
  is_exists boolean;
BEGIN
  IF NOT EXISTS(select 1 FROM fhir.resource WHERE _id = update_resource.id) THEN
    RAISE EXCEPTION 'Resource with id % not found', id;
  ELSE
    PERFORM fhir.delete_resource(id);
    PERFORM fhir.insert_resource(resource_data, null::uuid, id);
  END IF;
  RETURN 0::integer;
END
$$;
