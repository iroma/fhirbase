-- db: test
--{{{
create view meta.complex_types as (
select dt.type
, count(*) as num_attrs
, array_agg(de.name) as attrs
from meta.datatypes dt
join meta.datatype_elements de on de.datatype = dt.type
group by dt.type
order by type
);

create view meta.enums as (
select type
, count(*) as num_options
, array_agg(value) as options
from meta.datatypes dt
join meta.datatype_enums de on de.datatype = dt.type
group by type
);

create view meta.primitives as (
select type from meta.datatypes
where
type not in (select distinct(datatype) from meta.datatype_enums)
and type not in (select distinct(datatype) from meta.datatype_elements)
and extension not in (select distinct(datatype) from meta.datatype_enums)
);
--}}}
