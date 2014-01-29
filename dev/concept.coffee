algorithm:
  _create_schema()
where:
  underscore: ()->
  _create_schema = ->
    deps:
      underscore
    algorithm:
      _create_base_tables(deps: underscore)
      _create_datatype_tables(deps: underscore)
      _create_resource_tables(deps: underscore)
    where:
      util: ()->
      _create_base_tables: ()->
        deps:
          underscore
        algorithm:
          tables = _find_tables
          _generate_table(tables, deps: deps.underscore)
        where:
          _find_tables: ()->
          _generate_table: ()->
            deps.underscore()
      _create_resource_tables: ()->
        deps:
          underscore
        algorithm:
          tables = _find_tables
          _generate_table(tables, deps: underscore)
        where:
          _find_tables: ()->
          _generate_table: ()->

