this.sql  = {
  fields_to_insert: function(columns, obj){
    return columns.reduce(function(acc, m){
      var an = m.column_name
      if(obj[an]){ acc[an] = obj[an] }
    return acc;
    },{})
  }
}

this.u = {
  log: function(mess){
    plv8.elog(NOTICE, JSON.stringify(mess));
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
