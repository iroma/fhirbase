create or replace function fhir.insert_resource(jdata json) returns uuid language plpythonu as $$
  import json
  import re

  def walk(parents, name, obj, cb):
    res = cb(parents, name, obj)
    new_parents = list(parents)
    new_parents.append({'name': name, 'obj': obj, 'meta': res})
    for key, value in obj.items():
      if isinstance(value, dict):
        walk(new_parents, key, value, cb)
      elif isinstance(value, list):
        def walk_through_list(elem):
          if isinstance(elem, dict):
            walk(new_parents, key, elem, cb)
        map(walk_through_list, value)

  def walk_function(parents, name, obj):
    pth = map(lambda x: underscore(x['name']), parents)
    pth.append(name)
    table_name = get_table_name(pth)

    if table_exists(table_name):
      attrs = collect_attributes(table_name, obj)
      if len(parents) > 1 and 'parent_id' not in attrs:
        attrs['parent_id'] = parents[-1]['meta']
      if len(parents) > 0:
        if 'parent_id' not in attrs:
          attrs['parent_id'] = parents[0]['meta']
        if 'resource_id' not in attrs:
          attrs['resource_id'] = parents[0]['meta']

      if 'id' not in attrs:
        attrs['id'] = uuid()

      insert_record('fhir', table_name, attrs)
      return attrs['id']
    else:
      log('Skip %s with path %s' % (table_name, pth))

  def insert_record(schema, table_name, attrs):
    attrs['_type'] = table_name
    query = """
      INSERT INTO %(schema)s.%(table)s
      SELECT * FROM json_populate_recordset(null::%(schema)s.%(table)s, '%(json)s'::json)
    """ % { 'schema': schema, 'table': table_name, 'json': json.dumps([attrs]) }
    plpy.execute(query)

  def uuid():
    sql = 'select uuid_generate_v4() as uuid'
    return plpy.execute(sql)[0]['uuid']

  # http://inflection.readthedocs.org/en/latest/_modules/inflection.html#camelize
  def camelize(string, uppercase_first_letter=True):
    if uppercase_first_letter:
      return re.sub(r"(?:^|_)(.)", lambda m: m.group(1).upper(), string)
    else:
      return string[0].lower() + camelize(string)[1:]

  # http://inflection.readthedocs.org/en/latest/_modules/inflection.html#underscore
  def underscore(word):
    word = re.sub(r"([A-Z]+)([A-Z][a-z])", r'\1_\2', word)
    word = re.sub(r"([a-z\d])([A-Z])", r'\1_\2', word)
    word = word.replace("-", "_")
    return word.lower()

  def get_table_name(path):
    args = ','.join(map(lambda e: plpy.quote_literal(e), path))
    sql = 'SELECT table_name(ARRAY[%s])' % args
    return plpy.execute(sql)[0]['table_name']

  def table_exists(table_name):
    query =  """
      select table_name
      from information_schema.tables
      where table_schema = 'fhir'
      """
    if not('table_names' in SD):
      SD['table_names'] = map(lambda d: d['table_name'], plpy.execute(query))

    return table_name in SD['table_names']

  def log(x):
    plpy.notice(x)

  def get_columns(table_name):
    if not('columns' in SD):
      query = """
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'fhir'
      """
      def reduce_function(acc, value):
        key = value['table_name']
        if key not in acc:
          acc[key] = set([])
        acc[key].add(value['column_name'])
        return acc

      SD['columns'] = reduce(reduce_function, plpy.execute(query), {})
    return SD['columns'][table_name]

  def collect_attributes(table_name, obj):
    #TODO: quote literal
    def arr2lit(v):
      return '{%s}' % ','.join(map(lambda e: '"%s"' % e, v))

    columns = get_columns(table_name)
    def is_column(k):
      return k in columns

    def is_unknown_attribute(v):
      return not(isinstance(v, dict) or isinstance(v, list))

    def coerce(v):
      if isinstance(v, list):
        return arr2lit(v)
      else:
        return v;

    attrs = {}
    for k, v in obj.items():
      key = underscore(k)
      if is_column(key):
        attrs[key] = coerce(v)
      elif is_unknown_attribute(v):
        if '_unknown_attributes' not in attrs:
          attrs['_unknown_attributes'] = {}
        attrs['_unknown_attributes'][k] = coerce(v)
    if '_unknown_attributes' in attrs:
      attrs['_unknown_attributes'] = json.dumps(attrs['_unknown_attributes'])
    return attrs


  data = json.loads(jdata)
  if 'id' not in data:
    data['id'] = uuid()
  walk([], underscore(data['resourceType']), data, walk_function)
  return data['id']
$$;
