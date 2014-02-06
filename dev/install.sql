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
create or replace function nested(path varchar[], level integer)
  returns varchar
  language plpgsql
  as $$
  BEGIN
				return path[1] || level::varchar || case
				when array_length(path, 1) > 1 then ' (' || nested(array_tail(path), level + 1) || ', ' || nested(array_tail(path), level + 1) || ')'
				else ''
        end;
  END
$$;
select nested(array['a', 'b', 'c', 'd'], 1)
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
								select path[1] as type_name, array_reverse(array_pop(array_reverse(path))) as subpath, *
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
drop function if exists nested(varchar[]) cascade;
create or replace function nested(var_path varchar[])
  returns varchar
  language plpgsql
  as $$
  declare
  level integer;
  columns varchar;
  selects varchar;
  BEGIN
				level := array_length(var_path, 1);
        select array_to_string(array_agg('t' || level::varchar || '.' || underscore(array_last(n.path))), ', ')
				into columns
				from meta.nested n
				join meta.primitive_types pt on underscore(pt.type) = underscore(n.type)
				where array_pop(n.path) = var_path;

				
				select array_to_string(array_agg(E'\n' || repeat('    ', level - 1) || '  (' || nested(n.path) || E'\n' || repeat('    ', level - 1) || '  ) as ' || underscore(array_last(n.path)) || E',\n'), ', ')
				into selects
				from meta.nested n
				left join meta.primitive_types pt on underscore(pt.type) = underscore(n.type)
				where pt.type is null and array_pop(n.path) = var_path;

				return E'\n' || repeat('    ', level - 1) || 'select array_to_json(array_agg(row_to_json(t_' || level::varchar || ', true)), true)' ||
        E'\n' || repeat('    ', level - 1) || 'from (' ||
				E'\n' || repeat('    ', level - 1) || '  select ' ||
				case when selects is not null then selects || repeat('    ', level - 1) else '' end ||
				columns ||
				E'\n' || repeat('    ', level - 1) || '  from ' || underscore(array_to_string(var_path, '_')) || ' t' || level::varchar ||
				E'\n' || repeat('    ', level - 1) || '  where t' || level::varchar || '.root_id = t1.id and t' || level::varchar || '.parent_id = t' || (level - 1)::varchar || '.id' ||
        E'\n' || repeat('    ', level - 1) || ') t_' || level::varchar;
				--return level::varchar || ': (' ||
			  --					columns ||
				--				' from ' || underscore(array_to_string(var_path, '_')) || ')' ||
				--case when selects is not null then E',\n' || repeat('  ', level) || '(' || selects || ')' else '' end;
				--' || case when level = 1 then 'id, ' else '' end || '
				--case when level > 1 then 
  END
$$;
select nested(array['Patient']);--, 'address', 'period']);
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
