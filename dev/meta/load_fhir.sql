--db:testfhir
--{{{
\set medapp `cat $FHIR_HOME/fhir/test/profiles-resources.xml`

create OR replace
function xattr(pth varchar, x xml) returns varchar
  as $$
  BEGIN
    return  unnest(xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']])) limit 1;
  END
$$ language plpgsql;


create OR replace
function fpath(pth varchar, x xml) returns xml[]
  as $$
  BEGIN
    return xpath(pth, x, ARRAY[ARRAY['fh', 'http://hl7.org/fhir']]);
  END
$$ language plpgsql;

create OR replace
function xarrattr(pth varchar, x xml) returns varchar[]
  as $$
  BEGIN
    RETURN array(select unnest(fpath(pth, x))::varchar);
  END
$$ language plpgsql;

INSERT INTO meta.resource_elements
 (version, path, min, max, type)
select
    '0.12' as version,
    regexp_split_to_array(xattr('./path/@value', el), '\.') as path,
    xattr('./definition/max/@value', el) as max,
    xattr('./definition/min/@value', el) as max,
    xarrattr('./definition/type/code/@value', el) as type
  FROM (
    SELECT unnest(fpath('//fh:structure/fh:element', :'medapp')) as el
  ) els
;
---}}}
