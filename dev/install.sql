--db:testfhir
--{{{
drop schema if exists meta cascade;
\ir sql/meta.sql
\ir sql/load_meta.sql
\ir sql/plv8.sql
\ir sql/load_plv8_modules.sql
\ir sql/functions.sql
\ir sql/datatypes.sql
\ir sql/schema.sql
\timing

select * from meta.resource_tables;

do language plv8 $$
  load_module('schema')
  sql.generate_schema('0.12')
$$;

do language plv8 $$
  load_module('views')
  views.generate_views('fhirr')
$$;
--}}}
--{{{
create or replace view meta.nested as (
select *
from (
				select
				r.path || t.subpath as path,
				coalesce(t.type, r.type) as type,
				coalesce(t.min, r.min) as min,
				coalesce(t.max, r.max) as max
				from (
								select *
								from meta.expanded_resource_elements
				) r
				left join (
								select path[1] as type_name, array_tail(path) as subpath, *
								from meta.datatype_unified_elements
				) t on t.type_name = r.type
				union
				select
				r.path,
				r.type,
				r.min,
				r.max
				from (
								select path,
								type,
								min, max
								from meta.expanded_resource_elements
				) r
) w
order by array_to_string(w.path, '_')
);

--select *
--from meta.nested;
select array_to_string(array_agg(array_last(n.path)), ', ')
from meta.nested n
join meta.primitive_types pt on underscore(pt.type) = underscore(n.type)
where array_pop(n.path) = array['Patient']::varchar[];
select array_last(n.path), n.type
from meta.nested n
left join meta.primitive_types pt on underscore(pt.type) = underscore(n.type)
where pt.type is null and array_pop(n.path) = array['Patient']::varchar[];

select array_to_json(array_agg(row_to_json(t_4, true)), true)
from (
				select t4.system, t4.version, t4.code, t4.display, t4.primary
				from fhirr.encounter_hospitalization_special_arrangement_cd t4
--				where t4.encounter_id = t1.id and t4.encounter_hospitalization_special_arrangement_id = t3.id
) t_4;
--}}}
--{{{
select array_to_json(array_agg(row_to_json(t2, true)), true)
from (
				select
				(
								nested(path)
				) as period,
				(
								nested(path)
				) as period,
				t2.use,t2.text,t2.line,t2.city,t2.state,t2.zip,t2.country
				from fhir.patient_address t2
				WHERE t2.patient_id = t1.id
) t2
																																																																																															--}}}
