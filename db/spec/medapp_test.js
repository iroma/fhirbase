var fs = require('fs')
var assert = require('assert')
var text = fs.readFileSync('../js/medapp.js','utf8')

var plv8 = {}

eval(text);

function eq(x,y){
  assert(JSON.stringify(x) === JSON.stringify(y), 'Not equal ' + JSON.stringify(x) + ' != ' + JSON.stringify(y))
}

var columns = [{column_name: 'a'}]
var attrs = {a: 1, b: 2}

eq(this.sql.fields_to_insert(columns, attrs), {a: 1})

console.log('underscore');
eq(this.str.underscore("MaxBodnarchuk"), 'max_bodnarchuk')
eq(this.str.underscore("Max-Bodnarchuk"), 'max_bodnarchuk')
eq(this.str.underscore("maxBodnarChuk"), 'max_bodnar_chuk')

console.log('camelize');
eq(this.str.camelize('max_bodnarchuk'), "maxBodnarchuk")
eq(this.str.camelize('max_bodnarchuk'), "maxBodnarchuk")
eq(this.str.camelize('max_bodnar_chuk'), "maxBodnarChuk")

console.log('isObject');
assert(this.u.isObject({}));
assert(!this.u.isObject([]));
assert(!this.u.isObject(1));
assert(!this.u.isObject('vasiliy'));
assert(!this.u.isObject(new Date()));
assert(!this.u.isObject(false));
assert(!this.u.isObject(true));

console.log('normalize_keys');
var norm = {
  NikolayRyzhikov: {
    MikhailRyzhikov: 1,
    VasiliyPupkin: [{NoYes: 2}]
  }
};
console.log(JSON.stringify(this.sql.normalize_keys(norm)));
