// Generated by CoffeeScript 1.6.3
(function() {
  var camelize, collect_attributes, collect_columns, columns, e, get_table_name, insert_record, isObject, log, schema, self, table_exists, underscore, uuid, walk;

  self = this;

  log = function(mess, message) {
    if (message) {
      return plv8.elog(NOTICE, message, JSON.stringify(mess));
    } else {
      return plv8.elog(NOTICE, JSON.stringify(mess));
    }
  };

  e = function() {
    return plv8.execute.apply(plv8, arguments);
  };

  schema = 'fhirr';

  uuid = function() {
    var sql;
    sql = 'select uuid_generate_v4() as uuid';
    return plv8.execute(sql)[0]['uuid'];
  };

  isObject = function(obj) {
    return Object.prototype.toString.call(obj) === "[object Object]";
  };

  camelize = function(str) {
    return str.replace(/[-_\s]+(.)?/g, function(match, c) {
      if (c) {
        return c.toUpperCase();
      } else {
        return "";
      }
    });
  };

  underscore = function(str) {
    return str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase();
  };

  get_table_name = function(pth) {
    return plv8.execute('SELECT table_name($1)', [pth])[0].table_name;
  };

  table_exists = function(table_name) {
    var query;
    query = "select table_name from information_schema.tables where table_schema = '" + schema + "'";
    table_exists.existed_tables || (table_exists.existed_tables = plv8.execute(query).map(function(i) {
      return i.table_name;
    }));
    return table_exists.existed_tables.indexOf(table_name) > -1;
  };

  walk = function(parents, name, obj, cb) {
    var key, new_parents, res, value, _results;
    res = cb.call(self, parents, name, obj);
    new_parents = parents.concat({
      name: name,
      obj: obj,
      meta: res
    });
    _results = [];
    for (key in obj) {
      value = obj[key];
      if (isObject(value)) {
        _results.push(walk(new_parents, key, value, cb));
      } else if (Array.isArray(value)) {
        _results.push(value.map(function(v) {
          if (isObject(v)) {
            return walk(new_parents, key, v, cb);
          }
        }));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  };

  insert_record = function(schema, table_name, attrs) {
    attrs._type = table_name;
    return plv8.execute("insert into " + schema + "." + table_name + "\n(select * from\njson_populate_recordset(null::" + schema + "." + table_name + ", $1::json))", [JSON.stringify([attrs])]);
  };

  collect_columns = function() {
    var cols;
    cols = plv8.execute("select table_name, column_name from information_schema.columns where table_schema = '" + schema + "'", []);
    return cols.reduce((function(acc, col) {
      acc[col.table_name] = acc[col.table_name] || [];
      acc[col.table_name].push(col);
      return acc;
    }), {});
  };

  columns = function(table_name) {
    columns.columns_for || (columns.columns_for = collect_columns());
    return columns.columns_for[table_name];
  };

  collect_attributes = function(table_name, obj) {
    var arr2lit;
    arr2lit = function(v) {
      v = v.map(function(i) {
        return "\"" + i + "\"";
      }).join(',');
      return "{" + v + "}";
    };
    return columns(table_name).reduce((function(acc, m) {
      var an, col_prefix, column_name, parts, v;
      column_name = m.column_name;
      an = camelize(column_name);
      v = obj[an];
      parts = column_name.match(/(.*)_reference/);
      if (parts) {
        col_prefix = parts[1];
        if (v = obj[camelize(col_prefix)]) {
          acc[column_name] = v.reference;
          acc["" + col_prefix + "_display"] = v.display;
        }
      } else if (v) {
        if (Array.isArray(v)) {
          acc[column_name] = arr2lit(v);
        } else {
          acc[column_name] = v;
        }
      }
      return acc;
    }), {});
  };

  this.insert_resource = function(json) {
    var resource_name;
    resource_name = json.resourceType;
    return walk([], underscore(resource_name), json, function(parents, name, obj) {
      var attrs, pth, table_name;
      pth = parents.map(function(i) {
        return underscore(i.name);
      });
      pth.push(name);
      table_name = get_table_name(pth);
      if (table_exists(table_name)) {
        attrs = collect_attributes(table_name, obj);
        if (parents.length > 1) {
          attrs.parent_id || (attrs.parent_id = parents[parents.length - 1].meta);
        }
        if (parents.length > 0) {
          attrs.resource_id || (attrs.resource_id = parents[0].meta);
          attrs.parent_id || (attrs.parent_id = parents[0].meta);
        }
        attrs.id || (attrs.id = uuid());
        insert_record(schema, table_name, attrs);
        return attrs.id;
      } else {
        return log("Skip " + table_name);
      }
    });
  };

}).call(this);
