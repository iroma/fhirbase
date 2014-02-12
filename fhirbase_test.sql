\set pt1 `cat ./test/pt1.json`
\set pt2 `cat ./test/pt2.json`

\timing
BEGIN;

CREATE EXTENSION pgtap;

SELECT plan(3);

SELECT COUNT(*) FROM (SELECT fhir.insert_resource(:'pt1') FROM generate_series(1,10)) gen;
SELECT COUNT(*) FROM (SELECT fhir.insert_resource(:'pt2') FROM generate_series(1,10)) gen;

SELECT has_schema('fhir'::name);
SELECT has_table('fhir'::name, 'patient'::name);
SELECT has_table('fhir'::name, 'patient_name'::name);

ROLLBACK;
