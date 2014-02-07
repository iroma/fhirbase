self = this
log = (mess, message)->
  if message
    plv8.elog(NOTICE, message, JSON.stringify(mess))
  else
    plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  log(arguments[0])
  plv8.execute.apply(plv8, arguments)

schema = 'fhirr'

uuid = ()->
  sql = 'select uuid_generate_v4() as uuid'
  plv8.execute(sql)[0]['uuid']

isObject = (obj) ->
  Object::toString.call(obj) is "[object Object]"

camelize = (str) ->
  str.replace /[-_\s]+(.)?/g, (match, c) ->
    (if c then c.toUpperCase() else "")

underscore = (str) ->
  str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase()


get_table_name = (pth) ->
  plv8.execute('SELECT table_name($1)',[pth])[0].table_name

table_exists = (table_name)->
  query = "select table_name from information_schema.tables where table_schema = '#{schema}'"
  table_exists.existed_tables ||= plv8.execute(query).map((i)-> i.table_name)
  table_exists.existed_tables.indexOf(table_name) > -1

walk = (parents, name, obj, cb)->
  res = cb.call(self, parents, name, obj)
  new_parents = parents.concat({name: name, obj: obj, meta: res})
  for key of obj
    value = obj[key]
    if isObject(value)
      walk(new_parents, key, value, cb)
    else if Array.isArray(value)
      value.map (v) ->
        if isObject(v)
          walk(new_parents, key, v, cb)

insert_record = (schema, table_name, attrs) ->
  # log(k) for k,v of attrs
  attrs._type = table_name
  plv8.execute """
  insert into #{schema}.#{table_name}
  (select * from
  json_populate_recordset(null::#{schema}.#{table_name}, $1::json))
  """, [JSON.stringify([attrs])]

collect_columns = ()->
  cols = plv8.execute("select table_name, column_name from information_schema.columns where table_schema = '#{schema}'", [])
  cols.reduce ((acc, col)->
    acc[col.table_name] = acc[col.table_name] || []
    acc[col.table_name].push(col)
    acc
  ), {}

get_columns = (table_name) ->
  get_columns.columns_for ||= collect_columns()
  get_columns.columns_for[table_name]

collect_attributes = (table_name, obj) ->
  arr2lit = (v)->
    v = v.map((i)-> "\"#{i}\"").join(',')
    "{#{v}}"

  columns_index = get_columns(table_name).reduce ((acc,m)->
    acc[m.column_name] = m
    acc
  ), {}

  is_column = (k)->
    columns_index[k]?

  is_unknown_attribute = (v)->
    !(isObject(v) || Array.isArray(v))

  coerce = (v)->
    if Array.isArray(v)
      arr2lit(v)
    else
      v

  attrs = {}

  for k,v of obj
    key = underscore(k)
    if is_column(key)
      attrs[key] = coerce(v)
    else if is_unknown_attribute(v)
      (attrs._unknown_attributes ||={})[k]=coerce(v)

  if attrs._unknown_attributes
    attrs._unknown_attributes = JSON.stringify(attrs._unknown_attributes)

  attrs

@insert_resource = (json) ->
  resource_name = json.resourceType
  json.id ||= uuid()
  walk [], underscore(resource_name), json, (parents, name, obj)->
    pth = parents.map((i)-> underscore(i.name))
    pth.push(name)
    table_name = get_table_name(pth)

    if table_exists(table_name)
      attrs = collect_attributes(table_name, obj)

      if parents.length > 1
        attrs.parent_id ||= parents[parents.length - 1].meta
      if parents.length > 0
        attrs.resource_id ||= parents[0].meta
        attrs.parent_id ||= parents[0].meta

      attrs.id ||= uuid()

      insert_record(schema, table_name, attrs)
      attrs.id
    else
      log("Skip #{table_name}")
  json.id
