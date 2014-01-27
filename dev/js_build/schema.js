// Generated by CoffeeScript 1.5.0
(function() {
  var e, log, self, underscore;

  self = this;

  log = function(mess) {
    return plv8.elog(NOTICE, JSON.stringify(mess));
  };

  e = function() {
    return plv8.execute.apply(plv8, arguments);
  };

  underscore = function(str) {
    return str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").toLowerCase();
  };

  this.sql = {
    resources: function(version) {
      return e("select * from meta.resources where version = $1", [version]);
    },
    pg_type: {
      code: 'varchar',
      dateTime: 'timestamp',
      string: 'varchar',
      uri: 'varchar',
      datetime: 'timestamp',
      instant: 'timestamp',
      boolean: 'boolean',
      base64_binary: 'bytea',
      integer: 'integer',
      decimal: 'decimal',
      sampled_data_data_type: 'text',
      date: 'date',
      id: 'varchar',
      oid: 'varchar'
    },
    table_attributes: function(version, path) {
      var q;
      q = "select * from meta.components\nwhere array_to_string(parent_path,'.') = $1\norder by path";
      return sql.extend_polimorpic(e(q, [path.join('.')]));
    },
    mk_polimorphic: function(name, type) {
      name = name.replace('[x]', '');
      return type.map(function(tp) {
        type = tp && sql.pg_type[tp];
        if (type) {
          return "\"" + name + "_" + (underscore(tp)) + "\" " + type;
        }
      }).filter(function(i) {
        return i;
      }).join(',');
    },
    name_from_path: function(path) {
      return underscore(path[path.length - 1]);
    },
    is_polimorphic: function(a) {
      var name;
      name = sql.name_from_path(a.path);
      return name.indexOf('[x]') > -1;
    },
    extend_polimorpic: function(attrs) {
      return attrs.reduce((function(i, acc) {
        if (sql.is_polimorphic(i)) {
          log(i);
        }
        return acc.push(i);
      }), []);
    },
    mk_columns: function(attrs) {
      return attrs.map(function(a) {
        var name, type;
        name = underscore(a.path[a.path.length - 1]);
        if (a.type && a.type.length > 1 && name.indexOf('[x]') > -1) {
          return sql.mk_polimorphic(name, a.type);
        } else {
          type = sql.pg_type[a.type && a.type[0]];
          if (type) {
            return "\"" + name + "\" " + type;
          }
        }
      }).filter(function(i) {
        return i;
      });
    },
    generate_schema: function(version) {
      var schema;
      schema = "fhirr";
      e("DROP SCHEMA IF EXISTS " + schema + " CASCADE;\nCREATE SCHEMA " + schema + ";\nCREATE TABLE " + schema + ".resource (\n   id uuid PRIMARY KEY,\n   resource_type varchar not null,\n   container_id uuid\n);\n\nCREATE TABLE " + schema + ".resource_component (\n  id uuid PRIMARY KEY,\n  resource_id uuid,\n  compontent_type varchar,\n  inline_id  uuid,\n  container_id uuid\n);");
      return sql.resources(version).forEach(function(r) {
        var attrs, components, table_name;
        table_name = underscore(r.type);
        components = sql.table_attributes(version, [r.type]);
        attrs = sql.mk_columns(components).join(',');
        e("CREATE TABLE " + schema + "." + table_name + " (\n " + attrs + "\n) INHERITS (" + schema + ".resource)");
        return components.forEach(function(a) {
          return sql.create_components_table(schema, version, a);
        });
      });
    },
    create_components_table: function(schema, version, comp) {
      var attrs, components, table_name;
      components = sql.table_attributes(version, comp.path);
      if (components.length > 0) {
        table_name = comp.path.map(underscore).join('_');
        attrs = sql.mk_columns(components).join(',');
        if (attrs) {
          e("CREATE TABLE " + schema + "." + table_name + " (\n  " + attrs + "\n) INHERITS (" + schema + ".resource_component)");
        }
        return components.forEach(function(a) {
          return sql.create_components_table(schema, version, a);
        });
      }
    }
  };

}).call(this);
