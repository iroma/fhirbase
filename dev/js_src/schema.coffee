self = this

log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  # log(arguments)
  plv8.execute.apply(plv8, arguments)

underscore = (str) ->
  str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase()

clone = (obj)->
  JSON.parse(JSON.stringify(obj))

@sql =

  generate_schema: (version)->
    schema = "fhirr"
    e """
     DROP SCHEMA IF EXISTS #{schema} CASCADE;
     CREATE SCHEMA #{schema};
    """
    sql.generate_enums(schema, version)

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
       compontent_type varchar,
       container_id uuid references #{schema}.resource (id)
     );

     CREATE TABLE #{schema}.resource_values (
       id uuid PRIMARY KEY,
       parent_id uuid references #{schema}.resource_component (id),
       resource_id uuid references #{schema}.resource (id),
       value_type varchar,
       container_id uuid references #{schema}.resource (id)
     );
    """

    sql.generate_datatypes_tables(schema, version)
    return

    sql.resources(version).forEach (r)->
      table_name = underscore(r.type)
      # TODO:  rename component into element
      components = sql.components(version, [r.type])
      attrs = sql.mk_columns(components).join(',')
      attrs = attrs && (',' + attrs)
      # TODO indexes
      e """
        CREATE TABLE #{schema}.#{table_name} (
         resource_type #{schema}."ResourceType" default '#{r.type}'
         #{attrs}
        ) INHERITS (#{schema}.resource)
      """
      components.forEach (a)->
        sql.create_components_table(schema, version, a)

  generate_enums: (schema, version)->
    e("SELECT * from meta.enums").forEach (en)->
      opts = en.options.map((i)-> "'#{i}'").join(',')
      e """
      CREATE TYPE #{schema}.\"#{en.enum}\"
      AS ENUM (#{opts})
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

  generate_datatypes_tables: (schema, version)->
    deps = e("select datatype, array_agg(deps) as deps from meta.datatype_deps group by datatype")
      .reduce ((acc, i)->
        acc[i.datatype]= i.deps.filter((i)-> i)
        acc
      ), {}

    types =  sql.tsort(deps)
    types.forEach (tp)->
      log("TODO: create #{tp}")

    return
    dts = e """
      select de.datatype,
      array_agg(row_to_json(de.*)) attrs
      from meta.complex_datatypes cd
      join meta.datatype_elements de on de.datatype =  cd.type
      join meta.complex_datatypes cdd on cdd.type = de.type
      where cd.type not in ('Resource', 'BackboneElement', 'Extension', 'Narrative')
      group by datatype
    """

    dts.forEach (dt)->
      log(dt.datatype)
      log(dt.attrs.map((i)-> i.type))

  resources: (version) ->
    e("select * from meta.resources where version = $1", [version])

  primitive_pg_types:
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

  is_enum: (type)->
    e("select * from meta.enums where enum = $1",[type]).length > 0

  pg_type: (type)->
    if sql.is_enum(type)
      "fhirr.#{type}"
    else
      sql.primitive_pg_types[type]

  components: (version, path)->
    q = """
      select * from meta.components
      where array_to_string(parent_path,'.') = $1
      order by path
    """
    sql.expand_polimorpic(e(q, [path.join('.')]))

  name_from_path: (path)->
    underscore(path[path.length - 1]) if path

  is_polimorphic: (a)->
    name = sql.name_from_path(a.path)
    name.indexOf('[x]') > -1

  expand_polimorpic: (attrs)->
    attrs.reduce(((acc, at)->
      if sql.is_polimorphic(at)
        name = sql.name_from_path(at.path).replace('[x]','')
        at.type.map (tp)->
          obj = clone(at)
          obj.path[obj.path.length - 1] = "#{name}_#{tp}"
          obj.type = [tp]
          acc.push(obj)
      else
        acc.push(at)
      acc
    ), [])

  mk_columns: (attrs)->
    attrs.map(sql.mk_column)
      .filter((i) -> i && i.replace(/(^\s*|\s*$)/,''))

  mk_column: (a)->
    # TODO: array
    # TODO: constraints at least required
    name = underscore(a.path[a.path.length - 1])
    type = sql.pg_type(a.type && a.type[0])
    if type
      "\"#{name}\" #{type}"

  create_components_table: (schema, version, comp)->
    components = sql.components(version, comp.path)
    if components.length > 0
      table_name = comp.path.map(underscore).join('_')
      attrs = sql.mk_columns(components).join(',')
      if attrs
        e """
          CREATE TABLE #{schema}.#{table_name} (
            compontent_type varchar default '#{table_name}',
            #{attrs}
          ) INHERITS (#{schema}.resource_component)
        """
      components.forEach (a)->
        sql.create_components_table(schema, version, a)
