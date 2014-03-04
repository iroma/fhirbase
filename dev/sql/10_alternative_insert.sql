--db: fhir_build
--{{{
\set pt_json `cat ../test/fixtures/patient.json`
--SELECT :'pt_json'::json#>>'{identifier,0}';
--SELECT :'pt_json'::json#>>'{name,0, family}';


--contact -> id(contact)
--relation -> id(relation) + parent_id(contact)
--coding -> id(coding) + parent_id(relation)
--
--path, values, id, parent_id

WITH contacts AS (
  SELECT uuid_generate_v4() as uuid,
  ARRAY['contact'] as path, *
  from json_array_elements((:'pt_json'::json->'contact'))
)
, relationship AS (
  SELECT uuid_generate_v4() as uuid,
    array_append(path, 'relationship') as path,
    uuid as contact_id,
    json_array_elements(value->'relationship') as value
    FROM contacts
),
coding AS (
  SELECT uuid_generate_v4() as uuid,
    array_append(path, 'coding') as path,
    uuid as relationship_id,
    json_array_elements(value->'coding')
    FROM relationship
)
SELECT * from coding;
--}}}

SELECT * FROM (
  SELECT uuid_generate_v4() as uuid,
    a.uuid as contact_id,
    json_array_elements(a.value->'relationship')
  FROM (
        SELECT uuid_generate_v4() as uuid, *
        from json_array_elements((:'pt_json'::json->'contact'))
      ) a
) b;

--}}}
--{{{
--\dv meta.*
select 'WITH '
  || table_name
  || ' AS (
    SELECT uuid_generate_v4() as uuid,
    array_append(path, '''
  || fhir.array_last(path)
  || ''') as path,
    uuid as parent_id,
    json_array_elements(value->'''
  || fhir.array_last(path)
  || ''')
    FROM '
  || fhir.table_name(fhir.array_pop(path))
  || ')'
 ,*
from meta.resource_tables
where resource_table_name = 'patient'
and array_length(path, 1) > 1
order by path;
--}}}
--{{{
select *
FROM meta.resource_tables e
where e.path[2] = 'contact'
and e.path[1] = 'Patient'

--}}}

--}}}

CREATE OR REPLACE
FUNCTION walk_json(obj json)
  returns varchar
  language plpgsql
  as $$
  BEGIN
    RETURN obj;
  END
$$ IMMUTABLE;

\set pt_json `cat ../test/fixtures/patient.json`

--{{{
\dt pg_catalog.*
select * from pg_catalog.pg_constraint
where contype = 'f'
limit 10;
--}}}
\dv information_schema.*

select * from information_schema.referential_constraints;
--{{{
\set pt_json `cat ../test/fixtures/patient.json`
select fhir.underscore(key), value from (
        select * from json_each(:'pt_json'::json)) obj
      JOIN information_schema.columns dc
      on dc.column_name = fhir.underscore(key)
      where dc.table_name = 'patient'
      and dc.table_schema = 'fhir';
--}}}

select * from (
        select key, unnest(json_array_elements(value)) from json_each(:'pt_json'::json)) obj
      WHERE fhir.underscore(key) not in (
      select column_name FROM information_schema.columns dc
      where dc.table_name = 'patient'
      and dc.table_schema = 'fhir');

select * from information_schema.tables
where table_name = 'patient';


select * from json_each(:'pt_json'::json);
--select walk_json(:'pt_json'::json);
select * from json_populate_record(null::fhir.patient,:'pt_json'::json,  true);
select json_array_elements(:'pt_json'::json->'name');
select * from json_populate_recordset(null::fhir.patient_name, (:'pt_json'::json->'name')::json);

--select * from json_each(:'pt_json');

tree -> walk(item -> do) == foreach postgresql
tree -> walk -> [(path, record)] -> do
json_each ->
agg all simple values -> 1 row (path, agg of simple values of this level)
union
all hash -> [hash] ->
if is array -> join all values of array with recusion
--}}}
