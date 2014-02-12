create or replace function fhir.update_resource(id uuid, jdata json) returns integer language plpgsql as $$
  BEGIN
					select fhir.delete_resource(id);
					select fhir.insert_resource(jdata);
					return 0;
  END
$$;
