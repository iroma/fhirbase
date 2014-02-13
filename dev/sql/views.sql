CREATE TABLE meta.resource_elements_expanded_with_types AS
SELECT * FROM (
  SELECT
  r.path || t.subpath AS path,
  underscore(COALESCE(t.type, r.type)) AS type,
  COALESCE(t.min, r.min) AS min,
  COALESCE(t.max, r.max) AS max
  FROM (
    SELECT *
    FROM meta.expanded_resource_elements
  ) r
  LEFT JOIN (
    SELECT path[1] AS type_name, array_tail(path) AS subpath, *
    FROM meta.datatype_unified_elements
  ) t ON underscore(t.type_name) = underscore(r.type)
  UNION SELECT r.path, underscore(r.type), r.min, r.max FROM (
    SELECT path, type, min, max
    FROM meta.expanded_resource_elements
  ) r
) w ORDER BY array_to_string(w.path, '_');

CREATE INDEX resource_elements_expanded_with_types_type_idx
       ON meta.resource_elements_expanded_with_types (type);

CREATE INDEX resource_elements_expanded_with_types_popped_path_idx
       ON meta.resource_elements_expanded_with_types (array_pop(path));

DROP FUNCTION IF EXISTS select_containeds(uuid) CASCADE;
CREATE OR REPLACE FUNCTION select_containeds(cid uuid)
  RETURNS json
  LANGUAGE plpgsql
  AS $$
  DECLARE
    contained record;
    idx integer;
    query text;
    containeds_json json;
  BEGIN
    query := '';
    idx := 0;

    FOR contained IN SELECT r.id, table_name(ARRAY[r.resource_type]) as tbl
                              FROM fhir.resource r
                              WHERE r.container_id = cid LOOP

      query := (CASE WHEN query = '' THEN '' ELSE query || ' UNION ALL' END) ||
          ' SELECT v' || idx::varchar || '.json FROM fhir."view_' || contained.tbl || '_with_containeds" v' || idx::varchar ||
          ' WHERE v' || idx::varchar || '.id = ''' || contained.id || '''';

      idx := idx + 1;
    END LOOP;

    EXECUTE 'SELECT array_to_json(array_agg(t.json)) FROM (' || query || ') t'
    INTO containeds_json;

    RETURN containeds_json;
  END
$$;

DROP FUNCTION IF EXISTS gen_select_sql(varchar[], varchar) CASCADE;
CREATE OR REPLACE FUNCTION gen_select_sql(var_path varchar[], schm varchar)
  RETURNS varchar
  LANGUAGE plpgsql
  AS $$
  DECLARE
  level integer;
  isArray boolean;
  columns varchar;
  selects varchar;
  subselect text;
  BEGIN
    level := array_length(var_path, 1);

    SELECT n."max" = '*'
    INTO isArray
    FROM meta.resource_elements_expanded_with_types n
    WHERE n.path = var_path;

    SELECT array_to_string(array_agg('t' || level::varchar || '."' || underscore(array_last(n.path)) || '" as "' || camelize(array_last(n.path)) || '"'), ', ')
    INTO columns
    FROM meta.resource_elements_expanded_with_types n
    JOIN meta.primitive_types pt ON underscore(pt.type) = underscore(n.type)
    WHERE array_pop(n.path) = var_path;

    SELECT array_to_string(array_agg(E'(\n' || indent(gen_select_sql(n.path, schm), 3) || E'\n) as "' || camelize(array_last(n.path)) || '"'), E',\n')
    INTO selects
    FROM meta.resource_elements_expanded_with_types n
    LEFT JOIN meta.primitive_types pt on underscore(pt.type) = underscore(n.type)
    WHERE pt.type IS NULL AND array_pop(n.path) = var_path and array_last(n.path) not in ('contained');

    IF selects IS NULL AND columns IS NULL THEN
      RETURN 'NULL';
    ELSE
      subselect :=
         CASE WHEN level = 1 THEN '' ELSE E'\nselect ' END ||

         COALESCE(selects, '') ||
         (CASE WHEN selects IS NOT NULL AND columns IS NOT NULL THEN E',\n' ELSE '' END) ||
         COALESCE(columns, '') ||

         E'\nfrom ' ||
           '"' || schm || '"."' || table_name(var_path) || '" t' || level::varchar ||

         CASE WHEN level = 1 THEN
           -- E'\n where t' || level::varchar || '.container_id IS NULL'
           ''
         ELSE
           E'\nwhere t' ||
             level::varchar || '."resource_id" = t1."id" and t' ||
             level::varchar || '."parent_id" = t' ||
             (level - 1)::varchar || '."id"'
         END;

      IF level = 1 THEN
        RETURN 'select t1.id, (CASE WHEN t1.container_id IS NULL THEN select_containeds(t1.id) ELSE NULL END) as "contained", ' || subselect;
      ELSE
        RETURN
          CASE WHEN isArray THEN
            'select array_to_json(array_agg(row_to_json(t_' || level::varchar || ', true)), true) from ('
            || indent(subselect, 1)
            || E'\n) t_' || level::varchar
          ELSE
            'select row_to_json(t_' || level::varchar || ', true) from ('
            || indent(subselect, 1)
            || E'\n) t_' || level::varchar
          END;
      END IF;
    END IF;
  END
$$;

DROP FUNCTION IF EXISTS create_resource_view(varchar, varchar) CASCADE;
CREATE OR REPLACE FUNCTION create_resource_view(resource_name varchar, schm varchar)
  RETURNS void
  LANGUAGE plpgsql
  AS $$
  DECLARE
  res_table_name varchar;
  BEGIN
    -- RAISE NOTICE 'Create JSON view for %', resource_name;

    res_table_name := table_name(ARRAY[resource_name]);

    EXECUTE
      'CREATE OR REPLACE VIEW "' || schm ||'"."view_' || res_table_name || '_with_containeds" AS ' ||
      'SELECT t_1.id, row_to_json(t_1, true) AS json, res_table.container_id AS container_id FROM (' ||
      E'\n' || indent(gen_select_sql(ARRAY[resource_name], schm), 1) ||
      ') t_1 JOIN fhir.' || res_table_name || ' res_table ON res_table.id = t_1.id;';

    EXECUTE
      'CREATE OR REPLACE VIEW fhir."view_' || res_table_name || '" AS SELECT id, json ' ||
      'FROM fhir."view_' || res_table_name || '_with_containeds" WHERE container_id IS NULL';
  END
$$;

-- run view generator for all resources
SELECT create_resource_view(path[1], 'fhir')
  FROM meta.expanded_resource_elements
  WHERE array_length(path, 1) = 1 AND path[1] <> 'Profile';
