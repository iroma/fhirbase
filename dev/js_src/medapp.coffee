self = this
log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  plv8.execute.apply(plv8, arguments)

@sql =
  log: (mess)->
    plv8.elog(NOTICE, JSON.stringify(mess))

  insert_record: (table_name, attrs) ->
    plv8.execute "insert into #{table_name} (select * from json_populate_recordset(null::#{table_name}, $1::json))", [JSON.stringify([attrs])]

  table_exists: (table_name)->
    self.sql.exited_tables ||= plv8.execute("select table_name from information_schema.tables where table_schema = 'fhir'").map((i)-> i.table_name)
    self.sql.exited_tables.indexOf(table_name) > -1

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
      an = self.str.camelize(column_name)
      v = obj[an]
      parts = column_name.match(/(.*)_reference/)
      if parts
        col_prefix = parts[1]
        if v = obj[self.str.camelize(col_prefix)]
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

  insert_resource: (json) ->
		sql.uniform(json)
    resource_name = json.resourceType
    s = self.str
    sql = self.sql
    uuid = sql.uuid
    schema = 'fhir.'

    sql.walk [], s.underscore(resource_name), json, (parents, name, obj)->
      parents_prefix = sql.table_name(parents)
      table_name = s.underscore(name)
      if parents_prefix.length > 0
        table_name = parents_prefix + '_' + table_name
      # TODO loose references
      if sql.table_exists(table_name)
        attrs = sql.collect_attributes(table_name, obj)
        attrs.id ||= uuid()

        if parents.length > 0
          agg_key = parents[0].name + '_id'
          attrs[agg_key] = parents[0].meta
        if parents.length > 1
          parent_key = parents_prefix + '_id'
          attrs[parent_key] = parents[parents.length - 1].meta

        # sql.log(attrs)
        sql.insert_record(schema + table_name, attrs)

        attrs.id
      else
        # sql.log("Skip #{table_name}")

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

  uniform: (obj) ->
    for key of obj
      value = obj[key]
      if key.to_s == 'extension'
        ext = {}
        value.each do |e|
          e_key = e['url'].split("#").last.underscore
          e_value = e.select{|x, y| x.start_with?('value')}.first
          if e_value.present?
            ext[e_key] = e_value.last
        end
        value.clear
        value << ext
      if value.is_a?(Array)
        value.each do |v|
          if v.is_a?(Hash)
            sql.uniform(v)
      elsif value.is_a?(Hash)
        sql.uniform(value)
    end
  end

  expand: (obj, url) ->
    obj.each do |key, value|
      if key.to_s == 'extension'
        arr = []
        e = value.first
        if e
          e.each do |k, v|
            arr << {
              'url' => "#{url}\##{k}",
              'value' => v
            }
          end
        end
        value.clear
        arr.each do |a|
          value << a
        end
      end
      if value.is_a?(Array)
        value.each do |v|
          if v.is_a?(Hash)
            expand(v, url)
          end
        end
      elsif value.is_a?(Hash)
        expand(value, url)
      end
    end
  end

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
