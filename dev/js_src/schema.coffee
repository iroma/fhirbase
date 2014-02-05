self = this

log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  log(arguments[0])
  plv8.execute.apply(plv8, arguments)

@sql =

  generate_schema: (version)->
    schema = "fhirr"
    e """
     DROP SCHEMA IF EXISTS #{schema} CASCADE;
     CREATE SCHEMA #{schema};
    """

    e("SELECT * from meta.enums").forEach (en)->
      opts = en.options.map((i)-> "'#{i}'").join(',')
      e "CREATE TYPE #{schema}.\"#{en.enum}\" AS ENUM (#{opts})"

    e """
     CREATE TABLE #{schema}.resource (
        id uuid PRIMARY KEY,
        resource_type #{schema}."ResourceType" not null,
        language varchar,
        text xml,
        text_status #{schema}."NarrativeStatus",
        container_id uuid references #{schema}.resource (id)
     );

     CREATE TABLE #{schema}.resource_component (
       id uuid PRIMARY KEY,
       parent_id uuid references #{schema}.resource_component (id),
       resource_id uuid references #{schema}.resource (id),
       resource_compontent_type varchar,
       container_id uuid references #{schema}.resource (id)
     );

     CREATE TABLE #{schema}.resource_value (
       id uuid PRIMARY KEY,
       parent_id uuid references #{schema}.resource_component (id),
       resource_id uuid references #{schema}.resource (id),
       resource_value_type varchar,
       container_id uuid references #{schema}.resource (id)
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
        ) INHERITS (#{schema}.#{tbl.base_table})
      """
