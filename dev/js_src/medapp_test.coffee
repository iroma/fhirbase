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
debug = (mess) ->
  console.log JSON.stringify(mess)

self = this

self.sql.log = debug

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

fact "pluralize", ->
  eq(@str.pluralize('patient'), 'patients')
  eq(@str.pluralize('visit'), 'visits')
  eq(@str.pluralize('boy'), 'boys')
  eq(@str.pluralize('party'), 'parties')

fact 'collect_attributes', ->
  old_columns = @sql.columns
  @sql.columns = (x)->
    switch x
      when 'patients'
        [{column_name: 'id'}, {column_name: 'birth_date'}, {column_name: 'resource_type'}]
      else
        [{column_name: 'patient_id'}]

  attrs = @sql.collect_attributes('patients', self.pt)
  eq(attrs.birth_date, '1944-11-17')

fact 'insert_resource', ->
  # @sql.insert_record = (table_name, attrs)->
  #   console.log("insert into #{table_name} #{JSON.stringify(attrs)}")

  # counter = 0
  # @sql.uuid = ()->
  #   counter += 1

  # @sql.insert_resource(self.pt)
