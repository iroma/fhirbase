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
select dt.type
, count(*)
, array_agg(de.name)
from meta.datatypes dt
join meta.datatype_elements de on de.datatype = dt.type
group by dt.type
order by type
--}}}

--{{{
select * from meta.datatypes
where
type not in (select distinct(datatype) from meta.datatype_enums)
and type not in (select distinct(datatype) from meta.datatype_elements)
and extension not in (select distinct(datatype) from meta.datatype_enums)
;
--}}}

--{{{
select type, count(*) from meta.datatypes dt
join meta.datatype_enums de on de.datatype = dt.type
group by type
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

--{{{
select * from meta.elements
where array_length(path, 1) = 1
order by resource
--}}}
