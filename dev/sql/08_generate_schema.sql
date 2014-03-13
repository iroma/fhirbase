CREATE OR REPLACE FUNCTION meta.eval_ddl(str text)
RETURNS text AS
$BODY$
  begin
    EXECUTE str;
    RETURN str;
  end;
$BODY$
LANGUAGE plpgsql VOLATILE;


CREATE VIEW meta.enums_ddl AS(
  SELECT
    'CREATE TYPE'
    || ' fhir."' || enum  || '"'
    || ' AS ENUM ('
    || array_to_string( ( SELECT array_agg('$quote$' || unnest || '$quote$') FROM unnest(options)) , ',')
    || ')' as ddl
  FROM meta.enums
);

SELECT  meta.eval_ddl(ddl) FROM meta.enums_ddl;

CREATE TABLE fhir.resource (
  _id UUID PRIMARY KEY,
  _type VARCHAR NOT NULL,
  _unknown_attributes json,
  resource_type varchar,
  language VARCHAR,
  container_id UUID, --REFERENCES fhir.resource (_id) ON DELETE CASCADE DEFERRABLE,
  id VARCHAR
);

CREATE TABLE fhir.resource_component (
  _id uuid PRIMARY KEY,
  _type VARCHAR NOT NULL,
  _unknown_attributes json,
  parent_id UUID NOT NULL, --REFERENCES fhir.resource_component (_id) ON DELETE CASCADE DEFERRABLE,
  resource_id UUID NOT NULL -- REFERENCES fhir.resource (_id) ON DELETE CASCADE DEFERRABLE,
);

CREATE VIEW meta.datatypes_ddl AS (
SELECT
     'CREATE TABLE'
    ||  ' fhir."' || table_name  || '"'
    ||  '(' || array_to_string(columns, ',') || ')'
    ||  ' INHERITS (fhir.' || base_table || ')'
  AS ddl
  FROM meta.datatype_tables
 WHERE table_name NOT IN ('resource', 'backbone_element')
);

SELECT meta.eval_ddl(ddl) FROM meta.datatypes_ddl;

CREATE VIEW meta.resources_ddl AS (
SELECT
  ARRAY[
       'CREATE TABLE'
    || ' fhir."' || table_name  || '"'
    || '(' || array_to_string(columns, ',') || ')'
    || ' INHERITS (fhir.' || base_table || ')'
  , 'ALTER TABLE fhir.' || table_name || ' ALTER COLUMN _type SET DEFAULT $$' || table_name || '$$'
  ,'ALTER TABLE fhir.' || table_name || ' ADD PRIMARY KEY (_id)'
  ,CASE WHEN base_table = 'resource'
     THEN  --   'ALTER TABLE fhir.' || table_name || ' ADD FOREIGN KEY (container_id) REFERENCES fhir.resource (_id) ON DELETE CASCADE;' || -- problem with inheretance & foreign keys
          'CREATE INDEX ON fhir.' || table_name || ' (container_id);'
     ELSE    ''--'ALTER TABLE fhir.' || table_name || ' ADD FOREIGN KEY (resource_id) REFERENCES fhir.' || resource_table_name || ' (_id) ON DELETE CASCADE DEFERRABLE;'
          || 'CREATE INDEX ON fhir.' || table_name || ' (resource_id);'
          --|| 'ALTER TABLE fhir.' || table_name || ' ADD FOREIGN KEY (parent_id) REFERENCES fhir.' || parent_table_name || ' (_id) ON DELETE CASCADE DEFERRABLE;'
          || 'CREATE INDEX ON fhir.' || table_name || ' (parent_id);'
     END
  ] AS ddls
  FROM meta.resource_tables
  WHERE table_name !~ '^profile'
);


SELECT meta.eval_ddl(unnest)
  FROM ( SELECT unnest(ddls) FROM meta.resources_ddl) _;
