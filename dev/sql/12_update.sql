CREATE OR REPLACE FUNCTION fhir.update_resource(id uuid, resource_data json)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
num_of_deleted_rows integer;
BEGIN
  SELECT fhir.delete_resource(id);

  --IF num_of_deleted_rows = 0 THEN
  --  RAISE EXCEPTION 'Resource with id % not found', id;
  --END IF;

  PERFORM fhir.insert_resource(fhir.merge_json(resource_data, ('{ "_id": "' || id::varchar || '"}')::json));
  RETURN 0::integer;
END
$$;
