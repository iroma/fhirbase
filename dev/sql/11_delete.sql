CREATE OR REPLACE
FUNCTION delete_resource(_id uuid)
  returns integer
  language sql
  as $$
  WITH res_comp_del AS (
    DELETE FROM fhir.resource WHERE id = _id
  )
  DELETE FROM fhir.resource_component WHERE resource_id = _id RETURNING 1; -- FIXME: return number of rows
$$ IMMUTABLE;
