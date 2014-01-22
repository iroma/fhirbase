var self = this;

this.sql  = {
  fields_to_insert: function(columns, obj){
    return columns.reduce(function(acc, m){
      var an = m.column_name
      if(obj[an]){ acc[an] = obj[an] }
      return acc;
    },{})
  },
  insert_obj: function (name, obj){
    return plv8.execute(
      'insert into ' + name +' (select * from json_populate_recordset(null::' + name + ', $1::json))'
      , [JSON.stringify([obj])]);
  },
  columns: function(table_name){
    return plv8.execute(
      'select column_name from information_schema.columns where table_name = $1', [table_name])

  },
  insert_resource: function(json){
    json = normalize_keys(json);
    plv8.elog(NOTICE, str.underscore(json.resourceType));
  },
  normalize_keys: function(json) {
    var new_json = {}
    for (var key in json) {
      var value = json[key]
      if (self.u.isObject(value)) {
        value = self.sql.normalize_keys(value);
      } else if (Array.isArray(value)) {
        value = value.map(function(v) {
          if (self.u.isObject(v)) {
            return self.sql.normalize_keys(v);
          } else {
            return v;
          }
        })
      }
      new_json[self.str.underscore(key)] = value;
    }
    return new_json;
  }
}

this.u = {
  log: function(mess){
    plv8.elog(NOTICE, JSON.stringify(mess));
  },
  isObject: function(obj){
    return Object.prototype.toString.call(obj) == '[object Object]';
  }
}

this.str = {
  underscore: function(str){
    return str.replace(/([a-z\d])([A-Z]+)/g, '$1_$2').replace(/[-\s]+/g, '_').toLowerCase();
  },
  camelize: function(str){
    return str.replace(/[-_\s]+(.)?/g, function(match, c){ return c ? c.toUpperCase() : ""; });
  }
}
