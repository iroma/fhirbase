self = this
@sql =
  log: (mess)->
    plv8.elog(NOTICE, JSON.stringify(mess))

  insert_record: (table_name, attrs) ->
    plv8.execute "insert into #{table_name} (select * from json_populate_recordset(null::#{table_name}, $1::json))", [JSON.stringify([attrs])]

  columns: (table_name) ->
    plv8.execute "select column_name from information_schema.columns where table_name = $1", [table_name]

  collect_attributes: (table_name, obj) ->
    columns = self.sql.columns(table_name)
    columns.reduce ((acc, m) ->
      an = self.str.camelize(m.column_name)
      self.sql.log(m)
      acc[m.column_name] = obj[an] if obj[an]
      acc
    ), {}

  uuid: ()->
    sql = 'select uuid_generate_v4() as uuid'
    plv8.execute(sql)[0]['uuid']

  insert_resource: (json) ->
    resource_name = json.resourceType
    s = self.str
    sql = self.sql
    uuid = sql.uuid
    schema = 'fhir.'

    sql.walk [], s.underscore(resource_name), json, (parents, name, obj)->
      attrs = sql.collect_attributes(s.pluralize(name), obj)
      attrs.id ||= uuid()

      table_name = s.pluralize(name)
      if parents.length > 0
        agg_key = parents[0].name + '_id'
        attrs[agg_key] = parents[0].meta
        table_name = sql.table_name(parents) + "_#{table_name}"
      if parents.length > 1
        parent_key = sql.table_name(parents) + '_id'
        attrs[parent_key] = parents[parents.length - 1].meta

      sql.insert_record(schema + table_name, attrs)

      attrs.id

  table_name: (parents) ->
    parents.map((i)-> self.str.underscore(i.name)).join('_')

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
  log: (mess) ->
    plv8.elog NOTICE, JSON.stringify(mess)

  isObject: (obj) ->
    Object::toString.call(obj) is "[object Object]"

@str =
  underscore: (str) ->
    str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase()

  camelize: (str) ->
    str.replace /[-_\s]+(.)?/g, (match, c) ->
      (if c then c.toUpperCase() else "")

  is_vowel: (char) ->
    /[aeiou]/.test char if char.length is 1
  tabelize: (str)->
    s = self.str
    s.pluralize(s.underscore(str))
  pluralize: (str) ->
    if str.slice(-1) is "y"
      if self.str.is_vowel((str.charAt(str.length - 2)))
        str + "s"
      else
        str.slice(0, -1) + "ies"
    else if str.substring(str.length - 2) is "us"
      str.slice(0, -2) + "i"
    else if ["ch", "sh"].indexOf(str.substring(str.length - 2)) isnt -1 or ["x", "s"].indexOf(str.slice(-1)) isnt -1
      str + "es"
    else
      str + "s"
