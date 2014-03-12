--db: fhir_build
--{{{
CREATE OR REPLACE FUNCTION meta.eval_function(str text)
RETURNS text AS
$BODY$
  begin
    EXECUTE str;
    RETURN str;
  end;
$BODY$
LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE
FUNCTION meta.eval_insert(str text)
RETURNS text AS
$$
  BEGIN
    EXECUTE str;
    RETURN 'inserted';
  END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE
FUNCTION json_array_to_array_literal(json)
RETURNS text
AS $$
   SELECT quote_literal(replace(replace($1::text, '[', '{'), ']','}'));
$$ IMMUTABLE LANGUAGE sql;

CREATE MATERIALIZED VIEW
fhir_columns AS (
    SELECT
       column_name
      ,data_type
      ,table_name
    FROM information_schema.columns
    WHERE table_schema = 'fhir'
);
CREATE INDEX fhir_columns_column_name_idx ON fhir_columns
(column_name);
CREATE INDEX fhir_columns_table_name ON fhir_columns
(table_name);

-- build insert string from json and table meta info
CREATE OR REPLACE
FUNCTION build_insert_statment(_table_name text, _obj json, _id text, _parent_id text, _resource_id text)
RETURNS text
AS $$

-- TODO: support _unknown fields
WITH vals AS ( -- split json into key-value filter only columns
  SELECT fhir.underscore(a.key) as key,
         a.value as value,
         column_info.data_type as data_type
    FROM json_each_text(_obj) a
    JOIN fhir_columns column_info
      ON column_info.table_name = _table_name
     AND column_info.data_type IS NOT NULL
     AND fhir.underscore(a.key) = column_info.column_name
), key_vals AS (
    SELECT vals.key as key,
           CASE WHEN vals.data_type = 'ARRAY'
            THEN json_array_to_array_literal(vals.value::json)
            ELSE quote_literal(vals.value)
          END AS value
      FROM vals
      UNION
        SELECT '_id' AS key, quote_literal(_id) AS value
      UNION
        SELECT 'parent_id' AS key, quote_literal(_parent_id) AS value
        WHERE _parent_id IS NOT NULL
      UNION
        SELECT 'resource_id' AS key, quote_literal(_resource_id) AS value
        WHERE _parent_id IS NOT NULL AND _resource_id <> _id
)
select 'insert into '
   || 'fhir.' || _table_name
   || ' (' || string_agg(key, ',') || ') '
   || ' VALUES (' || string_agg(value, ',') || ')'
   FROM key_vals b;
$$ LANGUAGE sql VOLATILE;
--}}}
