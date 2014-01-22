eq = (x, y) ->
  assert JSON.stringify(x) is JSON.stringify(y), "Not equal " + JSON.stringify(x) + " != " + JSON.stringify(y)
fact = (name, cb) ->
  try
    cb.call self
    process.stdout.write "."
  catch e
    console.log name
    console.log e
    console.error e.stack
debug = (obj) ->
  console.log JSON.stringify(obj)

self = this

fact "underscore", ->
  eq @str.underscore("MaxBodnarchuk"), "max_bodnarchuk"
  eq @str.underscore("Max-Bodnarchuk"), "max_bodnarchuk"
  eq @str.underscore("maxBodnarChuk"), "max_bodnar_chuk"

fact "camelize", ->
  eq @str.camelize("max_bodnarchuk"), "maxBodnarchuk"
  eq @str.camelize("max_bodnarchuk"), "maxBodnarchuk"
  eq @str.camelize("max_bodnar_chuk"), "maxBodnarChuk"

fact "isObject", ->
  assert @u.isObject({})
  assert not @u.isObject([])
  assert not @u.isObject(1)
  assert not @u.isObject("vasiliy")
  assert not @u.isObject(new Date())
  assert not @u.isObject(false)
  assert not @u.isObject(true)

fact "normalize_keys", ->
  obj = NikolayRyzhikov:
    MikhailRyzhikov: 1
    VasiliyPupkin: [NoYes: 2]

  nobj = @sql.normalize_keys(obj)
  # debug(nobj)
  eq nobj.nikolay_ryzhikov.vasiliy_pupkin[0].no_yes, 2
  eq nobj.nikolay_ryzhikov.mikhail_ryzhikov, 1

fact "pluralize", ->
  eq(@str.pluralize('patient'), 'patients')
  eq(@str.pluralize('visit'), 'visits')
  eq(@str.pluralize('boy'), 'boys')
  eq(@str.pluralize('party'), 'parties')
