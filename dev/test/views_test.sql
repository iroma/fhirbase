\ir 'spec_helper.sql'

BEGIN;

SELECT plan(2);

INSERT INTO fhirr.patient (id, resource_type, birth_date)
       VALUES(uuid_generate_v1(), 'Patient', '12-12-1987');

SELECT is(
       (SELECT COUNT(*) FROM fhirr.patient),
       1::bigint,
       'only one patient inserted');

SELECT is(
       (SELECT birth_date::varchar FROM fhirr.view_patient LIMIT 1),
       '1987-12-12 00:00:00',
       'receive correct birth_date from patient view');

SELECT * FROM finish();
ROLLBACK;
