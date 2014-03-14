CREATE OR REPLACE
FUNCTION fhir.delete_resource(_id uuid)
  returns void
  language sql
  as $$
  DELETE FROM fhir.resource WHERE _id = delete_resource._id;
$$;
