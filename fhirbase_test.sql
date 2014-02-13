\set pt1 `cat ./test/pt1.json`
\set pt2 `cat ./test/pt2.json`

BEGIN;

CREATE EXTENSION pgtap;

SELECT plan(7);

SELECT COUNT(*) FROM (SELECT fhir.insert_resource(:'pt1') FROM generate_series(1,20)) gen;

SELECT has_schema('fhir'::name);
SELECT has_table('fhir'::name, 'patient'::name);
SELECT has_table('fhir'::name, 'patient_name'::name);

SELECT is(COUNT(*)::integer, 20, 'total 20 patients inserted')
       FROM fhir.view_patient;

SELECT id AS first_id FROM fhir.patient LIMIT 1 \gset
SELECT id AS second_id FROM fhir.patient LIMIT 1 OFFSET 1 \gset

SELECT ok(fhir.delete_resource(:'first_id') > 0,
       'first patient was deleted');

SELECT ok(fhir.update_resource(:'second_id', :'pt2'::json) = 0,
       'second patient was updated');

SELECT is((SELECT (((json)->'identifier')->0->>'value')::varchar
       FROM fhir.view_patient
       WHERE id = :'second_id'),
       '12345'::varchar,
       'second patient''s data was actualy changed');

ROLLBACK;
