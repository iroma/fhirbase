create or replace function fhir.update_resource(id uuid, jdata json) returns integer language plpgsql as $$
  BEGIN
					perform fhir.delete_resource(id);
					perform fhir.insert_resource(jdata);
					return 0::integer;
  END
$$;
