create OR replace function underscore(str varchar)
  returns varchar
  language plpgsql
  as $$
  BEGIN
   return lower(
    replace(
      regexp_replace(
        regexp_replace(str, '([a-z\d])([A-Z]+)', '\1_\2', 'g'),
        '[-\s]+', '_', 'g'),
      '.',
      ''));
  END
$$ IMMUTABLE;

-- remove last item from array
CREATE OR REPLACE
FUNCTION array_pop(ar varchar[])
  RETURNS varchar[] language plpgsql AS $$
  BEGIN
    return ar[array_lower(ar,1) : array_upper(ar,1) - 1];
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
FUNCTION table_name(path varchar[])
  RETURNS varchar LANGUAGE plpgsql AS $$
  BEGIN
    RETURN underscore(
      array_to_string(
         array_agg(
          coalesce(
            (SELECT alias
               FROM meta.word_aliases
              WHERE word = nm limit 1)
            , nm)), '_'))
       FROM unnest(path) as nm;
  END
$$ IMMUTABLE;

