self = this

log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  log(arguments[0])
  plv8.execute.apply(plv8, arguments)

@sql =
  generate_schema: (schema, version)->
    e """
     DROP SCHEMA IF EXISTS #{schema} CASCADE;
     CREATE SCHEMA #{schema};
    """

    e("SELECT * from meta.enums").forEach (en)->
      opts = en.options.map((i)-> "'#{i}'").join(',')
      e "CREATE TYPE #{schema}.\"#{en.enum}\" AS ENUM (#{opts})"

    e """
     CREATE TABLE #{schema}.resource (
        id UUID PRIMARY KEY,
        _type VARCHAR NOT NULL,
        _unknown_attributes json,
        resource_type varchar,
        language VARCHAR,
        container_id UUID REFERENCES #{schema}.resource (id)
     );

     CREATE TABLE #{schema}.resource_component (
       id uuid PRIMARY KEY,
       _type VARCHAR NOT NULL,
       _unknown_attributes json,
       parent_id UUID NOT NULL REFERENCES #{schema}.resource_component (id),
       resource_id UUID NOT NULL REFERENCES #{schema}.resource (id),
       container_id UUID REFERENCES #{schema}.resource (id)
     );
    """

    e("select * from meta.datatype_tables where table_name not in ('resource', 'backbone_element') ").forEach (tbl)->
      e """
        CREATE TABLE #{schema}.#{tbl.table_name} (
          #{tbl.columns && tbl.columns.join(',')}
        ) INHERITS (#{schema}.#{tbl.base_table})
      """

    e("select * from meta.resource_tables").forEach (tbl)->
      e  """
        CREATE TABLE #{schema}.#{tbl.table_name} (
          #{tbl.columns}
        ) INHERITS (#{schema}.#{tbl.base_table});
        ALTER TABLE #{schema}.#{tbl.table_name}
          ALTER COLUMN _type SET DEFAULT '#{tbl.table_name}';
      """
