@log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

@column_name = (name, type)->
  name.replace('[x]', "_#{type}")

@underscore = (str)->
  str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2")
    .replace(/[-\s]+/g, "_")
    .replace('.','')
    .toLowerCase()

@table_name = (path)->
  underscore(path.join('_'))

@short_table_name = (path)->
  first = path[0]
  num_from_end = path.len - Math.min(path.length - 1, 2)
  len = path.length
  hvost = path.slice(num_from_end, len)
  underscore(([path[0]].concat(hvost)).join('__'))

