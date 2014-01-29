self = this

log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
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

    e("select * from meta.tables_ddl").forEach (tbl)->
      e """
        CREATE TABLE #{schema}.#{tbl.table_name} (
          #{tbl.columns}
        ) INHERITS (#{schema}.#{tbl.parent_table})
      """

  tsort: (deps)->
    deps_sutisfied = (deps, available)->
      deps
        .filter(((i)-> available.indexOf(i) == -1))
        .length == 0

    collect = (deps, resolved, guard)->
      resolved.push(tp) for tp, dp of deps when resolved.indexOf(tp) == -1 && deps_sutisfied(dp, resolved)
      if guard > 0
        collect(deps, resolved, guard - 1)
      else
        resolved

    collect(deps, [], 10)
