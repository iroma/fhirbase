CREATE OR REPLACE FUNCTION generate_schema2(schema text, version text)
  RETURNS VOID LANGUAGE plpythonu AS $$
  def exe(query):
    return plpy.execute(query)

  def make_enums(en):
    return "CREATE TYPE %(schema)s.%(enum)s AS ENUM (%(opts)s)" % {
      "schema": schema,
      "enum": en['enum'],
      "opts": map(lambda i: "'%s'" % i, en['options']) }

  def make_datatypes(e):
    columns = "\n".join(e['columns']) if 'columns' in e else ''

    return """
      CREATE TABLE %(schema)s.%(table)s (
        %(columns)s
      ) INHERITS (%(schema)s.%(base_table)s)""" % {
      "schema": schema,
      "table": e['table_name'],
      "base_table": e['base_table'],
      "columns": columns }

  def make_resources(e):
    columns = "\n".join(e['columns']) if 'columns' in e else ''

    return """
      CREATE TABLE %(schema)s.%(table)s (
        %(columns)s
      ) INHERITS (%(schema)s.%(base_table)s);

      ALTER TABLE %(schema)s.%(table)s
        ALTER COLUMN _type SET DEFAULT '%(table)s'
      """ % {
      "schema": schema,
      "table": e['table_name'],
      "base_table": e['base_table'],
      "columns": columns }

  queries = [
    "DROP SCHEMA IF EXISTS %s CASCADE" % schema,
    "CREATE SCHEMA %s" % schema
  ]

  queries.append("""
    CREATE TABLE %(schema)s.resource (
      id UUID PRIMARY KEY,
      _type VARCHAR NOT NULL,
      _unknown_attributes json,
      resource_type varchar,
      language VARCHAR,
      container_id UUID REFERENCES %(schema)s.resource (id)
    );

    CREATE TABLE %(schema)s.resource_component (
     id uuid PRIMARY KEY,
     _type VARCHAR NOT NULL,
     _unknown_attributes json,
     parent_id UUID NOT NULL REFERENCES %(schema)s.resource_component (id),
     resource_id UUID NOT NULL REFERENCES %(schema)s.resource (id),
     container_id UUID REFERENCES %(schema)s.resource (id)
    );
  """ % { "schema": schema })

  queries += map(make_enums, exe("SELECT * FROM meta.enums"))
  queries += map(make_datatypes, exe("SELECT * FROM meta.datatype_tables WHERE table_name NOT IN ('resource', 'backbone_element')"))
  queries += map(make_resources, exe("SELECT * FROM meta.resource_tables"))

  plpy.notice("\n".join(queries))
$$;

