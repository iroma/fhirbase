CREATE OR REPLACE FUNCTION fhir.update_resource(id uuid, resource_data json)
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE
num_of_deleted_rows integer;
BEGIN
  SELECT fhir.delete_resource(id) INTO num_of_deleted_rows;

  IF num_of_deleted_rows = 0 THEN
    RAISE EXCEPTION 'Resource with id % not found', id;
  END IF;

  PERFORM fhir.insert_resource(fhir.merge_json(resource_data, ('{ "id": "' || id::varchar || '"}')::json));
  RETURN 0::integer;
END
$$;
