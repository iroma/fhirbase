self = this

log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  plv8.execute.apply(plv8, arguments)

underscore = (str) ->
  str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase()

@sql =
  resources: (version) ->
    e("select * from meta.resources where version = $1", [version])
  pg_type:
    code: 'varchar'
    dateTime: 'timestamp'
    string: 'varchar'
    uri: 'varchar'
    datetime: 'timestamp'
    instant: 'timestamp'
    boolean: 'boolean'
    base64_binary: 'bytea'
    integer: 'integer'
    decimal: 'decimal'
    sampled_data_data_type: 'text'
    date: 'date'
    id: 'varchar'
    oid: 'varchar'

  table_attributes: (version, path)->
    q = """
      select * from meta.components
      where array_to_string(parent_path,'.') = $1
      order by path
    """
    e(q, [path.join('.')])

  mk_polimorphic: (name, type)->
    name = name.replace('[x]','')
    type.map (tp)->
      type = tp && sql.pg_type[tp]
      if type
        "\"#{name}_#{underscore(tp)}\" #{type}"
    .filter((i) -> i)
    .join(',')

  mk_columns: (attrs)->
    attrs.map (a)->
      name = underscore(a.path[a.path.length - 1])
      if a.type && a.type.length > 1 && name.indexOf('[x]') > -1
        sql.mk_polimorphic(name, a.type)
      else
        type = sql.pg_type[a.type && a.type[0]]
        if type
          "\"#{name}\" #{type}"
    .filter (i) -> i

  generate_schema: (version)->
    schema = "fhirr"
    e """
     DROP SCHEMA IF EXISTS #{schema} CASCADE;
     CREATE SCHEMA #{schema};
     CREATE TABLE #{schema}.resource (
        id uuid PRIMARY KEY,
        resource_type varchar not null,
        inline_id  uuid,
        container_id uuid
     );

     CREATE TABLE #{schema}.resource_component (
       id uuid PRIMARY KEY,
       resource_id uuid,
       compontent_type varchar,
       inline_id  uuid,
       container_id uuid
     );
    """
    sql.resources(version).forEach (r)->
      table_name = underscore(r.type)
      components = sql.table_attributes(version, [r.type])
      attrs = sql.mk_columns(components).join(',')
      e "CREATE TABLE #{schema}.#{table_name} ( #{attrs}) inherits (#{schema}.resource)"
      components.forEach (a)->
        sql.create_components_table(schema, version, a)

  create_components_table: (schema, version, comp)->
    components = sql.table_attributes(version, comp.path)
    if components.length > 0
      table_name = comp.path.map(underscore).join('_')
      attrs = sql.mk_columns(components).join(',')
      if attrs
        e("CREATE TABLE #{schema}.#{table_name} (#{attrs}) inherits (#{schema}.resource_component)")
      components.forEach (a)->
        sql.create_components_table(schema, version, a)
