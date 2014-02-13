CREATE OR REPLACE FUNCTION generate_schema(version TEXT)
  RETURNS VOID LANGUAGE plpythonu AS $$

  def exe(query):
    return plpy.execute(query)

  def create_object(func, query):
    return map(func, exe(query))

  def q(literal):
    return '"%s"' % literal

  def make_columns(e):
    if 'columns' in e:
      cols = map(lambda c: '%s' % c, e['columns'])
      return ",\n".join(cols)
    else:
      return ''

  def make_enums(en):
    return "CREATE TYPE fhir.%(enum)s AS ENUM (%(opts)s)" % {
      "enum": q(en['enum']),
      "opts": ','.join(map(lambda i: "'%s'" % i, en['options'])) }

  def make_datatypes(e):
    return """
      CREATE TABLE fhir.%(table)s (
        %(columns)s
      ) INHERITS (fhir.%(base_table)s)""" % {
      "table": e['table_name'],
      "base_table": e['base_table'],
      "columns": make_columns(e) }

  def make_resources(e):
    create_table = """
      CREATE TABLE fhir.%(table)s (
        %(columns)s
      ) INHERITS (fhir.%(base_table)s);

      ALTER TABLE fhir.%(table)s
        ALTER COLUMN _type SET DEFAULT '%(table)s';

      ALTER TABLE fhir.%(table)s
        ADD PRIMARY KEY (id);
      """ % {
      "table": e['table_name'],
      "base_table": e['base_table'],
      "columns": make_columns(e) }

    if e['base_table'] == 'resource':
      create_fk = ""
      create_indexes = ""
    else:
      create_fk = """
        ALTER TABLE fhir.%(table_name)s
          ADD FOREIGN KEY (resource_id) REFERENCES fhir.%(resource_table_name)s (id) ON DELETE CASCADE;
        ALTER TABLE fhir.%(table_name)s
          ADD FOREIGN KEY (parent_id) REFERENCES fhir.%(parent_table_name)s (id) ON DELETE CASCADE;
      """ % e
      create_indexes = """
        CREATE INDEX ON fhir.%(table_name)s (resource_id);
        CREATE INDEX ON fhir.%(table_name)s (parent_id);
      """ % e
    return ";\n".join([create_table, create_fk, create_indexes])

  queries = [
    "DROP SCHEMA IF EXISTS fhir CASCADE",
    "CREATE SCHEMA fhir",
    """
    CREATE TABLE fhir.resource (
      id UUID PRIMARY KEY,
      _type VARCHAR NOT NULL,
      _unknown_attributes json,
      resource_type varchar,
      language VARCHAR,
      container_id UUID REFERENCES fhir.resource (id) ON DELETE CASCADE
    );

    CREATE TABLE fhir.resource_component (
     id uuid PRIMARY KEY,
     _type VARCHAR NOT NULL,
     _unknown_attributes json,
     parent_id UUID NOT NULL REFERENCES fhir.resource_component (id) ON DELETE CASCADE,
     resource_id UUID NOT NULL REFERENCES fhir.resource (id) ON DELETE CASCADE,
     container_id UUID REFERENCES fhir.resource (id) ON DELETE CASCADE
    );
    """
  ]

  queries += create_object(make_enums, "SELECT * FROM meta.enums")
  queries += create_object(make_datatypes, "SELECT * FROM meta.datatype_tables WHERE table_name NOT IN ('resource', 'backbone_element')")
  queries += create_object(make_resources, "SELECT * FROM meta.resource_tables WHERE table_name !~ '^profile'")
  for query in queries:
    #plpy.notice(query)
    exe(query)
$$;

select generate_schema('0.12'::text);
