--{{{
\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`
\timing

SELECT DISTINCT resource_id,
  meta.eval_insert(
    build_insert_statment(fhir.table_name(path)::text, value, id::text, parent_id::text, resource_id::text)
 )
FROM fhir.insert_patient(:'pt_json'::json)
WHERE value is NOT NULL;

SELECT fhir.insert_resource(:'pt_json'::json);

select count(*) from fhir.patient;
\timing
\set pt_json `cat ../test/fixtures/patient.json`
SELECT fhir.sql_insert_resource(:'pt_json');
SELECT fhir.insert_resource(:'pt_json'::json);
select count(*) from fhir.patient;
--}}}
