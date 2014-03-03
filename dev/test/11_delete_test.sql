--db:myfhir
--{{{
\ir '00_spec_helper.sql'
\ir ../install.sql

\set pt_json `cat $FHIRBASE_HOME/test/fixtures/patient.json`

BEGIN;
SELECT plan(8);

select fhir.insert_resource(:'pt_json'::json) as resource_id \gset

SELECT :'resource_id';

SELECT is(count(*)::integer, 1, 'insert patient')
       FROM fhir.patient;

SELECT is(count(*)::integer, 1, 'insert patient')
       FROM fhir.patient_name;

select fhir.delete_resource(:'resource_id');

SELECT is(count(*)::integer, 0, 'delete patient')
       FROM fhir.patient;

SELECT is(count(*)::integer, 0, 'delete patient')
       FROM fhir.patient_name;

-- regression test

select fhir.insert_resource(:'pt_json'::json) as resource_id \gset

SELECT is(count(*)::integer, 1, 'delete patient')
       FROM fhir.patient;

SELECT is(count(*)::integer, 1, 'insert patient')
       FROM fhir.patient_name;

delete from fhir.patient_name;

SELECT is(count(*)::integer, 1, 'delete patient')
       FROM fhir.patient;

SELECT is(count(*)::integer, 0, 'delete patient')
       FROM fhir.patient_name;

SELECT * FROM finish();
ROLLBACK;
--}}}
