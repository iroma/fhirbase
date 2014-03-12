CREATE OR REPLACE
FUNCTION delete_resource(_id uuid)
  returns void
  language sql
  as $$
  DELETE FROM fhir.resource WHERE _id = delete_resource._id CASCADE;
$$;
