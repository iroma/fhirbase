--db: fhir_build
--{{{
CREATE OR REPLACE FUNCTION meta.eval_insert(str text)
RETURNS text AS
$$
  begin
    EXECUTE str;
    RETURN 'ok';
  end;
$$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION json_array_to_array_literal(json)
RETURNS text IMMUTABLE LANGUAGE sql
AS $$
   SELECT quote_literal(replace(replace($1::text, '[', '{'), ']','}'));
$$;


DROP FUNCTION IF EXISTS build_insert_satement(text,json, text, text, text);
CREATE OR REPLACE
FUNCTION build_insert_satement(
    table_name text,
    obj json,
    id text,
    parent_id text,
    resource_id text)
RETURNS text
AS $$
select 'insert into '
   || 'fhir.' || table_name
   || ' (' || string_agg(fhir.underscore(b.key),',') || ') '
   || ' VALUES (' || string_agg(b.value, ',') || ')'
   from (
        WITH vals AS (
          SELECT fhir.underscore(a.key) as key,
                 a.value as value,
                 dc.data_type as data_type
            FROM json_each_text(obj) a
             INNER JOIN information_schema.columns dc
                ON a.key = dc.column_name::text
                AND dc.table_name = table_name
                AND dc.table_schema = 'fhir'
            --GROUP BY key, value, data_type
        )
        SELECT vals.key as key,
               CASE WHEN vals.data_type = 'ARRAY'
                THEN json_array_to_array_literal(vals.value::json)
                ELSE quote_literal(vals.value)
              END AS value
          FROM vals
          UNION
            SELECT 'id' AS key, quote_literal(id) AS value
          UNION
            SELECT 'parent_id' AS key, quote_literal(parent_id) AS value
            WHERE parent_id IS NOT NULL
          UNION
            SELECT 'resource_id' AS key, quote_literal(resource_id) AS value
            WHERE parent_id IS NOT NULL AND resource_id <> id
      ) b;
$$ LANGUAGE sql VOLATILE;

select meta.eval_ddl(
      $q$
        DROP FUNCTION IF EXISTS insrt(json);
        CREATE OR REPLACE FUNCTION insrt(json)
        RETURNS TABLE(resource_id uuid, id uuid, path text[], parent_id uuid, value json) AS
        $$

        WITH patient AS (
         SELECT uuid as resource_id, uuid, path, parent_id, value FROM (
           SELECT
              uuid_generate_v4() as uuid
              ,ARRAY['patient'] as path
              ,null::uuid as parent_id
              ,$1 as value
           ) _
      ), $q$
      || array_to_string(array_agg(cte),',')
      || E'\n'
      || array_to_string(array_agg(slct),E'\nUNION ALL\n')
      || E';\n$$ LANGUAGE sql;'
    )
FROM
(
  select
    E'\n'
    || table_name
    || ' AS (
        SELECT p.resource_id as resource_id,
        uuid_generate_v4() as uuid,
        array_append(p.path, ''' || fhir.array_last(path) || ''') as path,
        p.uuid as parent_id,
        '
    ||
      CASE WHEN max='*'
        THEN 'json_array_elements((p.value::json)->''' || fhir.array_last(path) || ''') as value'
        ELSE '((p.value::json)->''' || fhir.array_last(path) || ''') as value'
      END
    || E'\n FROM '
    || fhir.table_name(fhir.array_pop(path))
    || ' p WHERE p.value IS NOT NULL '
    || E'\n)' as cte,
    'SELECT * FROM ' || table_name as slct
  from meta.resource_tables
  where resource_table_name = 'patient'
  and array_length(path, 1) > 1
  order by path
) _;

\set pt_json `cat ../test/fixtures/patient.json`

SELECT
meta.eval_insert(
  build_insert_satement(fhir.table_name(path)::text, value, id::text, parent_id::text, resource_id::text)
)
FROM insrt(:'pt_json'::json)
where value is not null
order by path
;

--}}}
