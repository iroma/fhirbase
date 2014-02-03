--db:myfhir
--{{{
create OR replace function underscore(str varchar)
  returns varchar
  language plv8
  as $$
   return str.replace(/([a-z\d])([A-Z]+)/g, "$1_$2").replace(/[-\s]+/g, "_").replace('.','').toLowerCase();
$$;
--}}}
