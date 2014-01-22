self = this
@sql =
  fields_to_insert: (columns, obj) ->
    console.log('here')
    columns.reduce ((acc, m) ->
      an = m.column_name
      acc[an] = obj[an]  if obj[an]
      acc
    ), {}

  insert_obj: (name, obj) ->
    plv8.execute "insert into " + name + " (select * from json_populate_recordset(null::" + name + ", $1::json))", [JSON.stringify([obj])]

  columns: (table_name) ->
    plv8.execute "select column_name from information_schema.columns where table_name = $1", [table_name]

  insert_resource: (json) ->
    json = normalize_keys(json)
    plv8.elog NOTICE, str.underscore(json.resourceType)

  normalize_keys: (json) ->
    new_json = {}
    for key of json
      value = json[key]
      if self.u.isObject(value)
        value = self.sql.normalize_keys(value)
      else if Array.isArray(value)
        value = value.map((v) ->
          if self.u.isObject(v)
            self.sql.normalize_keys v
          else
            v
        )
      new_json[self.str.underscore(key)] = value
    new_json

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
