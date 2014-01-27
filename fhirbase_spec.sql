--db:myfhir
--{{{
\set pt1 `cat ./spec/pt1.json`
\set pt2 `cat ./spec/pt2.json`
\set ext `cat ./spec/extension.json`

\timing
select count(*) from (select insert_resource(:'pt1') from generate_series(1,10)) gen;
select count(*) from (select insert_resource(:'pt2') from generate_series(1,10)) gen;
select count(*) from (select insert_resource(:'ext') from generate_series(1,10)) gen;

do language plv8 $$
  plv8.elog(NOTICE, 'HELLO')
$$;
select * from fhir.patient_name;

--}}}
