var fs = require('fs')
var assert = require('assert')
var text = fs.readFileSync('../js/medapp.js','utf8')

var plv8 = {}

eval(text);

function eq(x,y){
  assert(JSON.stringify(x) === JSON.stringify(y), 'Not equal ' + JSON.stringify(x) + ' != ' + JSON.stringify(y))
}
var self= this;
function fact(name, cb){
  try {
    cb.call(self)
    process.stdout.write('.');
  }catch(e){
    console.log(name);
    console.log(e);
  }
}

function debug(obj){
  console.log(JSON.stringify(obj));
}

var columns = [{column_name: 'a'}]
var attrs = {a: 1, b: 2}

eq(this.sql.fields_to_insert(columns, attrs), {a: 1})

fact('underscore', function (){
eq(this.str.underscore("MaxBodnarchuk"), 'max_bodnarchuk')
eq(this.str.underscore("Max-Bodnarchuk"), 'max_bodnarchuk')
eq(this.str.underscore("maxBodnarChuk"), 'max_bodnar_chuk')
})

fact('camelize', function (){
eq(this.str.camelize('max_bodnarchuk'), "maxBodnarchuk")
eq(this.str.camelize('max_bodnarchuk'), "maxBodnarchuk")
eq(this.str.camelize('max_bodnar_chuk'), "maxBodnarChuk")
})

fact('isObject', function (){
assert(this.u.isObject({}));
assert(!this.u.isObject([]));
assert(!this.u.isObject(1));
assert(!this.u.isObject('vasiliy'));
assert(!this.u.isObject(new Date()));
assert(!this.u.isObject(false));
assert(!this.u.isObject(true));
})

fact('camelize', function (){
  var obj = {
    NikolayRyzhikov: {
      MikhailRyzhikov: 1,
      VasiliyPupkin: [{NoYes: 2}]
    }
  };
  var nobj = this.sql.normalize_keys(obj);

  // debug(nobj)
  eq(nobj.nikolay_ryzhikov.vasiliy_pupkin[0].no_yes, 2)
})
