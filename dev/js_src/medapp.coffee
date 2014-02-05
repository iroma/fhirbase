self = this
log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  plv8.execute.apply(plv8, arguments)

schema = 'fhir'

underscore = (str) ->
  str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase()

get_table_name = (pth) ->
  plv8.execute('SELECT table_name($1)',[pth])[0].table_name

table_exists = (table_name)->
  #FIXME: hardcode schema
  query = "select table_name from information_schema.tables where table_schema = 'fhir'"
  self.sql.existed_tables ||= plv8.execute(query).map((i)-> i.table_name)
  self.sql.existed_tables.indexOf(table_name) > -1

walk = (parents, name, obj, cb)->
  res = cb.call(self, parents, name, obj)
  new_parents = parents.concat({name: name, obj: obj, meta: res})
  for key of obj
    value = obj[key]
    if self.u.isObject(value)
      self.sql.walk(new_parents, key, value, cb)
    else if Array.isArray(value)
      value.map (v) ->
        if self.u.isObject(v)
          self.sql.walk(new_parents, key, v, cb)

@sql =
  insert_resource: (json) ->
    resource_name = json.resourceType
    schema = 'fhir.'

    walk [], underscore(resource_name), json, (parents, name, obj)->
      pth = parents.map((i)-> underscore(i.name))
      pth.push(name)
      table_name = get_table_name(pth)
      # log(table_name)
      # log(obj)
      if table_exists(table_name)
        log("going insert into #{table_name}")
        attrs = sql.collect_attributes(table_name, obj)
        attrs.id ||= sql.uuid()

        # if parents.length > 0
        #   agg_key = parents[0].name + '_id'
        #   attrs[agg_key] = parents[0].meta
        # if parents.length > 1
        #   parent_key = parents_prefix + '_id'
        #   attrs[parent_key] = parents[parents.length - 1].meta

        # # log(attrs)
        sql.insert_record(schema + table_name, attrs)

        attrs.id
      else
        log("Skip #{table_name}")

  insert_record: (table_name, attrs) ->
    plv8.execute "insert into #{table_name} (select * from json_populate_recordset(null::#{table_name}, $1::json))", [JSON.stringify([attrs])]


  columns: (table_name) ->
    self.sql.columns_for ||= self.sql.collect_columns()
    self.sql.columns_for[table_name]

  resources: (version) ->
    e("select * from meta.resources where version = $1", [version])

  collect_columns: ()->
    cols = plv8.execute("select table_name, column_name from information_schema.columns where table_schema = 'fhir'", [])
    cols.reduce ((acc, col)->
      acc[col.table_name] = acc[col.table_name] || []
      acc[col.table_name].push(col)
      acc
    ), {}

  collect_attributes: (table_name, obj) ->
    columns = self.sql.columns(table_name)
    arr2lit = (v)->
      v = v.map((i)-> "\"#{i}\"").join(',')
      "{#{v}}"

    columns.reduce ((acc, m) ->
      column_name = m.column_name
      an = u.camelize(column_name)
      v = obj[an]
      parts = column_name.match(/(.*)_reference/)
      if parts
        col_prefix = parts[1]
        if v = obj[u.camelize(col_prefix)]
          acc[column_name] = v.reference
          acc["#{col_prefix}_display"] = v.display
      else if v
        if Array.isArray(v)
          acc[column_name] = arr2lit(v)
        else
          acc[m.column_name] = v
      acc
    ), {}

  uuid: ()->
    sql = 'select uuid_generate_v4() as uuid'
    plv8.execute(sql)[0]['uuid']

  walk: (parents, name, obj, cb)->
    res = cb.call(self, parents, name, obj)
    new_parents = parents.concat({name: name, obj: obj, meta: res})
    for key of obj
      value = obj[key]
      if self.u.isObject(value)
        self.sql.walk(new_parents, key, value, cb)
      else if Array.isArray(value)
        value.map (v) ->
          if self.u.isObject(v)
            self.sql.walk(new_parents, key, v, cb)

@u =
  isObject: (obj) ->
    Object::toString.call(obj) is "[object Object]"


  camelize: (str) ->
    str.replace /[-_\s]+(.)?/g, (match, c) ->
      (if c then c.toUpperCase() else "")
