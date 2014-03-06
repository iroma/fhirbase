CREATE OR REPLACE
FUNCTION camelize(str varchar) RETURNS varchar LANGUAGE plpythonu AS $$
  import re

  def _camelize(string, uppercase_first_letter=True):
    if uppercase_first_letter:
      return re.sub(r"(?:^|_)(.)", lambda m: m.group(1).upper(), string)
    else:
      return string[0].lower() + _camelize(string)[1:]

  return _camelize(str, False)
$$ IMMUTABLE;

CREATE FUNCTION merge_json(left JSON, right JSON)
RETURNS json LANGUAGE plpythonu AS $$
  import simplejson as json
  l, r = json.loads(left), json.loads(right)
  l.update(r)
  j = json.dumps(l)
  return j
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION resource_table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore'](acc[0])
$$ IMMUTABLE;


CREATE OR REPLACE
FUNCTION resource_table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore'](acc[0])
$$ IMMUTABLE;
CREATE OR REPLACE

FUNCTION parent_table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore']('_'.join(acc[0:-1]))
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore']('_'.join(acc))
$$ IMMUTABLE;
