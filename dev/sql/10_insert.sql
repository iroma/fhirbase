--db: fhir_build
--{{{
CREATE OR REPLACE
FUNCTION def_insert_function(fn_name text, body text)
RETURNS text
AS $$
      SELECT 'DROP FUNCTION IF EXISTS fhir.insert_' || fn_name || '(json);
      CREATE OR REPLACE FUNCTION fhir.insert_' || fn_name || '(json)
      RETURNS TABLE(resource_id uuid, id uuid, path text[], parent_id uuid, value json) AS
      $fn$ ' || body || E';\n$fn$ LANGUAGE sql;';
$$ IMMUTABLE LANGUAGE sql;

CREATE OR REPLACE VIEW insert_ddls AS (
SELECT path[1] as resource,
       def_insert_function(
        fhir.underscore(path[1]),
        'WITH ' || string_agg(cte, E',\n') || E'\n'
        || string_agg('SELECT * FROM _' || fhir.table_name(path), E'\n UNION ALL ') || ';'
       ) as ddl
FROM (SELECT
  path,
  '_' || table_name || ' AS ('
  || CASE WHEN array_length(path,1)=1
      THEN
       'SELECT uuid as resource_id, uuid, path, parent_id, value
          FROM ( SELECT uuid_generate_v4() as uuid ,ARRAY[''' || path[1] || '''] as path ,null::uuid as parent_id ,$1 as value ) _)'
      ELSE
      E'\nSELECT'
      || E'\n    p.resource_id as resource_id,'
      || E'\n    uuid_generate_v4() as uuid,'
      || E'\n    ' || quote_literal(path::text) || '::varchar[] as path,'
      || E'\n    p.uuid as parent_id,'
      || CASE WHEN max='*'
          THEN E'\n    json_array_elements((p.value::json)->''' || fhir.array_last(path) || ''') as value'
          ELSE E'\n    ((p.value::json)->''' || fhir.array_last(path) || ''') as value'
        END
      || E'\n  FROM _' || fhir.table_name(fhir.array_pop(path)) || ' p '
      || ' WHERE p.value IS NOT NULL)'
    END as cte
from meta.resource_tables
ORDER BY PATH
) _
 GROUP BY PATH[1]
);

-- generate insert functions

SELECT meta.eval_function(ddl) FROM insert_ddls;

CREATE OR REPLACE FUNCTION
fhir.insert_resource(resource_ json)
RETURNS uuid AS
$BODY$
  DECLARE uuid_ uuid;
  BEGIN
    EXECUTE 'SELECT resource_id FROM
      (SELECT resource_id,
      count(
      meta.eval_insert(
        build_insert_statment(fhir.table_name(path)::text, value, id::text, parent_id::text, resource_id::text)
      ))
      FROM fhir.insert_' || fhir.underscore(resource_->>'resourceType') || '($1)
      WHERE value is NOT NULL
      group by resource_id) _'
      INTO uuid_
      USING resource_
      ;
    RETURN uuid_;
  END;
$BODY$
LANGUAGE plpgsql VOLATILE;
--}}}

