create or replace function fhir.update_resource(id uuid, jdata json) returns integer language plpgsql as $$
DECLARE
res integer;
BEGIN
				select fhir.delete_resource(id) into res;
				IF res = 0 THEN
								raise exception 'Resource with id % not found', id;
				END IF;
				perform fhir.insert_resource(jdata);
				return 0::integer;
	END
$$;
