CREATE TABLE meta.resource_elements_expanded_with_types AS
SELECT * FROM (
  SELECT
  r.path || t.subpath AS path,
  COALESCE(t.type, r.type) AS type,
  COALESCE(t.min, r.min) AS min,
  COALESCE(t.max, r.max) AS max
  FROM (
    SELECT *
    FROM meta.expanded_resource_elements
  ) r
  LEFT JOIN (
    SELECT path[1] AS type_name, array_tail(path) AS subpath, *
    FROM meta.datatype_unified_elements
  ) t ON t.type_name = r.type
  UNION SELECT r.path, r.type, r.min, r.max FROM (
    SELECT path, type, min, max
    FROM meta.expanded_resource_elements
  ) r
) w ORDER BY array_to_string(w.path, '_');

DROP FUNCTION IF EXISTS gen_select_sql(varchar[]) CASCADE;
CREATE OR REPLACE FUNCTION gen_select_sql(var_path varchar[])
  RETURNS varchar
  LANGUAGE plpgsql
  AS $$
  DECLARE
  level integer;
  columns varchar;
  selects varchar;
  subselect text;
  BEGIN
    level := array_length(var_path, 1);
    SELECT array_to_string(array_agg('t' || level::varchar || '."' || underscore(array_last(n.path)) || '"'), ', ')
    INTO columns
    FROM meta.resource_elements_expanded_with_types n
    JOIN meta.primitive_types pt ON underscore(pt.type) = underscore(n.type)
    WHERE array_pop(n.path) = var_path;

    SELECT array_to_string(array_agg(E'(\n' || indent(gen_select_sql(n.path), 3) || E'\n) as "' || underscore(array_last(n.path)) || '"'), E',\n')
    INTO selects
    FROM meta.resource_elements_expanded_with_types n
    LEFT JOIN meta.primitive_types pt on underscore(pt.type) = underscore(n.type)
    WHERE pt.type IS NULL AND array_pop(n.path) = var_path;

    IF selects IS NULL AND columns IS NULL THEN
      RETURN 'NULL';
    ELSE
      subselect :=
         CASE WHEN level = 1 THEN '' ELSE E'\nselect ' END ||

         COALESCE(selects, '') ||
         (CASE WHEN selects IS NOT NULL AND columns IS NOT NULL THEN E',\n' ELSE '' END) ||
         COALESCE(columns, '') ||

         E'\nfrom ' ||
           '"' || 'fhirr' || '"."' || table_name(var_path) || '" t' || level::varchar ||

         CASE WHEN level = 1 THEN '' ELSE
           E'\nwhere t' ||
             level::varchar || '."resource_id" = t1."id" and t' ||
             level::varchar || '."parent_id" = t' ||
             (level - 1)::varchar || '."id"'
         END;

      IF level = 1 THEN
        RETURN 'select t1.id, ' || subselect;
      ELSE
        RETURN 'select array_to_json(array_agg(row_to_json(t_' || level::varchar || ', true)), true) from ('
         || indent(subselect, 1)
         || E'\n) t_' || level::varchar;
      END IF;
    END IF;
  END
$$;

DROP FUNCTION IF EXISTS create_resource_view(varchar) CASCADE;
CREATE OR REPLACE FUNCTION create_resource_view(resource_name varchar)
  RETURNS void
  LANGUAGE plpgsql
  AS $$
  DECLARE
  create_sql text;
  BEGIN
    RAISE NOTICE 'Create JSON view for %', resource_name;

    create_sql :=
      'CREATE OR REPLACE VIEW "fhirr"."view_' || underscore(resource_name) || '" AS SELECT t_1.id, row_to_json(t_1, true) AS json FROM (' ||
      E'\n' || indent(gen_select_sql(ARRAY[resource_name]), 1) ||
      ') t_1;';

    EXECUTE create_sql;
  END
$$;

-- run view generator for all resources
SELECT create_resource_view(path[1])
  FROM meta.expanded_resource_elements
  WHERE array_length(path, 1) = 1;
