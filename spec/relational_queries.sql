--db:test
--db:medapp_dev
--{{{
select datatype, array_agg(name)
from meta.datatype_elements
group by datatype
order by datatype
--}}}

--{{{
select * from meta.datatypes
where extension is not null
order by type
--}}}

--{{{
select * from meta.datatypes
where
type not in (select distinct(datatype) from meta.datatype_elements)
and type not in (select distinct(datatype) from meta.datatype_enums)
and kind = 'complexType'
--}}}

--{{{
select path, min, max, short from meta.elements
where is_modifier = true
order by path
--}}}

--{{{
select path, type from meta.elements
where array_length(type, 1) > 1
order by path
--}}}
