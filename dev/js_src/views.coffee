self = this
log = (mess)->
  plv8.elog(NOTICE, JSON.stringify(mess))

e = ()->
  plv8.execute.apply(plv8, arguments)

@views =
  generate_views: (schema) ->
    view_name = 'patient'
    query = "select * from #{schema}.patient"

    e """
    CREATE VIEW \"#{schema}\".view_#{view_name} AS #{query};
    """

  generate_view: (schema, resource_name) ->
    2 + 2
