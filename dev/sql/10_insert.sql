--db: fff
--{{{
select row_to_json(json_each(c.value))
from json_array_elements('{"contained":[{"id":"id1", "foo":"bar"}, {"id":"id2", "name":"Joe"}]}'::json->'contained') c;
--}}}

-- get_nested_entity_from_json(max, path)
CREATE OR REPLACE
FUNCTION fhir.json_extract_value_ddl(max varchar, key varchar)
RETURNS text
AS $$
  SELECT CASE WHEN max='*'
    THEN 'json_array_elements((p.value::json)->''' || key || ''')'
    ELSE '((p.value::json)->''' || key || ''')'
  END;
$$ IMMUTABLE LANGUAGE sql;

--{{{

/* DROP VIEW IF EXISTS insert_ctes cascade; */
CREATE OR REPLACE VIEW insert_ctes AS (
SELECT
  path,
  CASE WHEN array_length(path,1)=1
    THEN
     fhir.eval_template($SQL$
       _{{table_name}}  AS (
         SELECT uuid as resource_id, uuid, path, _container_id as container_id, null::uuid as parent_id, value
            FROM (
              SELECT coalesce(_resource_id, uuid_generate_v4()) as uuid , ARRAY['{{resource}}'] as path, _data as value
         ) _
      )
     $SQL$,
     'resource', path[1],
     'table_name', table_name)
    ELSE
      fhir.eval_template($SQL$
         _{{table_name}}  AS (
           SELECT
             p.resource_id as resource_id,
             uuid_generate_v4() as uuid,
             {{path}}::text[] as path,
             null::uuid as container_id,
             p.uuid as parent_id,
             {{value}} as value
           FROM _{{parent_table}} p
           WHERE p.value IS NOT NULL
        )
        $SQL$,
        'table_name', table_name,
        'path', quote_literal(path::text),
        'value', fhir.json_extract_value_ddl(max, fhir.array_last(path)),
        'parent_table', fhir.table_name(fhir.array_pop(path))
      )
    END as cte
FROM meta.resource_tables
ORDER BY PATH
);
--}}}

CREATE OR REPLACE VIEW insert_ddls AS (
SELECT
  path[1] as resource,
  fhir.eval_template($SQL$
     --DROP FUNCTION IF EXISTS fhir.insert_{{fn_name}}(json, uuid);
     CREATE OR REPLACE FUNCTION fhir.insert_{{fn_name}}(_data json, _container_id uuid default null, _resource_id uuid default null)
     RETURNS TABLE(resource_id uuid, id uuid, path text[], container_id uuid, parent_id uuid, value json) AS
     $fn$
        WITH {{ctes}}
        {{selects}};
     $fn$
     LANGUAGE sql;
  $SQL$,
   'fn_name', fhir.underscore(path[1]),
   'ctes',array_to_string(array_agg(cte order by path), E',\n'),
   'selects', string_agg('SELECT * FROM _' || fhir.table_name(path), E'\n UNION ALL ')
  ) as ddl
 FROM insert_ctes
 GROUP BY path[1]
 HAVING path[1] <> 'Profile' -- fix profile
);

-- generate insert functions

SELECT 'create insert functions...' FROM (
   SELECT meta.eval_function(ddl) FROM insert_ddls
) _;

/* DO $$ */
/*   DECLARE */
/*     r RECORD; */
/*   BEGIN */
/*     FOR r IN SELECT * FROM insert_ddls LOOP */
/*       PERFORM meta.eval_function(r.ddl); */
/*     END LOOP; */
/*   END */
/* $$; */


CREATE OR REPLACE FUNCTION
fhir.insert_resource(_resource json, _container_id uuid default null, _resource_id uuid default null)
RETURNS uuid AS
$BODY$
  DECLARE
    uuid_ uuid;
    r record;
    sql text;
  BEGIN
     EXECUTE fhir.eval_template($SQL$
        SELECT DISTINCT resource_id FROM
        (
          SELECT resource_id,
                 meta.eval_insert(build_insert_statment( fhir.table_name(path)::text, value, id::text, parent_id::text, resource_id::text, container_id::text ))
          FROM fhir.insert_{{resource}}($1, $2, $3)
          WHERE value IS NOT NULL
          ORDER BY path
        ) _;
      $SQL$, 'resource', fhir.underscore(_resource->>'resourceType'))
    INTO uuid_ USING _resource, _container_id, _resource_id;

      FOR r IN SELECT * FROM json_array_elements(_resource->'contained') LOOP
        PERFORM fhir.insert_resource(r.value, uuid_);
      END LOOP;
    RETURN uuid_;
  END;
$BODY$
LANGUAGE plpgsql VOLATILE;
--}}}
