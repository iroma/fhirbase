--create schema functions;
set search_path = fhir, pg_catalog;

CREATE OR REPLACE
FUNCTION underscore(str varchar)
  returns varchar
  language sql
  as $$
  SELECT
   lower(
    replace(
      regexp_replace(
        regexp_replace(str, '([a-z\d])([A-Z]+)', '\1_\2', 'g'),
        '[-\s]+', '_', 'g'),
      '.', '')); -- problem with path: {schedule,repeat} with type Schedule.repeat
$$ IMMUTABLE;

-- remove last item from array
CREATE OR REPLACE
FUNCTION array_pop(ar varchar[])
  RETURNS varchar[] language plpgsql AS $$
  BEGIN
    return ar[array_lower(ar,1) : array_upper(ar,1) - 1];
  END
$$ IMMUTABLE;

-- remove last item from array
CREATE OR REPLACE
FUNCTION array_tail(ar varchar[])
  RETURNS varchar[] language plpgsql AS $$
  BEGIN
    return ar[2 : array_upper(ar,1)];
  END
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION array_last(ar varchar[])
  RETURNS varchar language plpgsql AS $$
  BEGIN
    return ar[array_length(ar,1)];
  END
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION parent_table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore']('_'.join(acc[0:-1]))
$$ IMMUTABLE;



CREATE OR REPLACE
FUNCTION resource_table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore'](acc[0])
$$ IMMUTABLE;

CREATE OR REPLACE
FUNCTION table_name(path varchar[])
RETURNS varchar LANGUAGE plpythonu AS $$
  plpy.execute('select fhir.py_init()')
  acc = GD['prepare_path'](path)
  return GD['underscore']('_'.join(acc))
$$ IMMUTABLE;

/* CREATE TABLE fhir.short_names (name varchar, alias varchar); */
/* INSERT INTO fhir.short_names (name, alias) */
/* VALUES */
/*     ('capabilities', 'cap'), */
/*     ('chanel', 'chnl'), */
/*     ('codeable_concept', 'cc'), */
/*     ('coding', 'cd'), */
/*     ('identifier', 'idn'), */
/*     ('immunization', 'imm'), */
/*     ('immunization_recommendation', 'imm_rec'), */
/*     ('location', 'loc'), */
/*     ('medication', 'med'), */
/*     ('medication_administration', 'med_adm'), */
/*     ('medication_dispense', 'med_disp'), */
/*     ('medication_prescription', 'med_prs'), */
/*     ('medication_statement', 'med_st'), */
/*     ('observation', 'obs'), */
/*     ('prescription', 'prs'), */
/*     ('recommentdaton', 'rcm'), */
/*     ('resource_reference', 'res_ref'), */
/*     ('value', 'val'), */
/*     ('value_set', 'vs') */
/* ; */
/* CREATE OR REPLACE */
/* FUNCTION fhir.table_name(path varchar[]) */
/* RETURNS varchar AS $$ */
/*   SELECT string_agg(part, '_') FROM ( */
/*     SELECT fhir.underscore(coalesce(sn.alias, pth.unnest)) as part */
/*       FROM (SELECT *, row_number() OVER () FROM unnest(path)) pth */
/*       LEFT JOIN fhir.short_names sn */
/*       ON sn.name = pth.unnest */
/*       ORDER BY row_number */
/*     ) _; */
/* $$ LANGUAGE sql IMMUTABLE; */

CREATE OR REPLACE FUNCTION indent(t text, l integer)
  RETURNS text LANGUAGE plpgsql AS $$
  BEGIN
    RETURN regexp_replace(t, '^', repeat('  ', l), 'gm');
  END
$$;

CREATE OR REPLACE
FUNCTION column_name(name varchar, type varchar)
  RETURNS varchar language plpgsql AS $$
  BEGIN
    return replace(name, '[x]', '_' || type);
  END
$$  IMMUTABLE;

CREATE OR REPLACE
FUNCTION column_ddl(column_name varchar, pg_type varchar, min varchar, max varchar)
  RETURNS varchar LANGUAGE plpgsql AS $$
  BEGIN
    return ('"' ||
      fhir.underscore(column_name) ||
      '" ' ||
      pg_type ||
      case
        when max = '*' then '[]'
        else ''
      end ||
      case
        when min = '1' then ' not null'
        else ''
      end);
  END
$$ IMMUTABLE;

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

set search_path = public, pg_catalog;
