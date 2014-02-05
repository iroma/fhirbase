// Generated by CoffeeScript 1.6.1
(function() {
  var e, log, self;

  self = this;

  log = function(mess) {
    return plv8.elog(NOTICE, JSON.stringify(mess));
  };

  e = function() {
    return plv8.execute.apply(plv8, arguments);
  };

  this.views = {
    generate_views: function(schema) {
      var query, view_name;
      view_name = 'patient';
      query = "select * from " + schema + ".patient";
      return e("CREATE VIEW \"" + schema + "\".view_" + view_name + " AS " + query + ";");
    },
    generate_view: function(schema, resource_name) {
      return 2 + 2;
    }
  };

}).call(this);
