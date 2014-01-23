var fs = require('fs')
var assert = require('assert')
var text = fs.readFileSync('../js_build/medapp.js','utf8')

var plv8 = {}
eval(text);
var js = fs.readFileSync('../js_build/pt.js','utf8')
eval(js);
var text = fs.readFileSync('../js_build/medapp_test.js','utf8')
eval(text);
