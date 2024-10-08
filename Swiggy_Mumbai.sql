select * from swiggy;

select 
sum(case when hotel_name='' then 1 else 0 end) as hotel,
sum(case when rating='' then 1 else 0 end) as rating,
sum(case when time_minutes='' then 1 else 0 end) as time_minutes,
sum(case when food_type='' then 1 else 0 end) as food_type,
sum(case when location='' then 1 else 0 end) as location,
sum(case when offer_above='' then 1 else 0 end) as offer_above,
sum(case when offer_percentage='' then 1 else 0 end) as offer_percentage
from swiggy;

/*this can be done for <10 number of columns but in case of higher number of columns, we use Automation*/

-- Automation
select * from information_schema.columns where table_name='swiggy';
select column_name from information_schema.columns where table_name='swiggy';

delimiter //
create procedure count_blank_rows()
begin
select group_concat(
(
concat('sum(case when `', column_name, '`='''' then 1 else 0 end)as`', column_name,'`') -- back quote is used to specify column name
)
)into @output
from information_schema.columns where table_name='swiggy';
set @output= concat('select ', @output, ' from swiggy');
prepare smt from @output;
execute smt;
deallocate prepare smt;
end //
delimiter;

call count_blank_rows();

-- Shifting values from rating to time_minutes
create table clean as select * from swiggy where rating like '%mins%';
create table cleaned as select *, f_name(rating) as 'rate' from clean; /* here delimiter is ' '*/ 
drop table clean;

select * from cleaned c inner join swiggy s on s.hotel_name=c.hotel_name;
set sql_safe_updates=0;
update swiggy s inner join cleaned c on s.hotel_name=c.hotel_name set s.time_minutes=c.rate;
drop table cleaned;

-- replacing time range with average
create table clean as select * from swiggy where time_minutes like '%-%';

create table cleaned as select *,f_name(time_minutes) t1,l_name(time_minutes) t2 from clean; /* here delimiter is '-' */
drop table clean;

update swiggy s inner join cleaned c on s.hotel_name=c.hotel_name set s.time_minutes=((c.t1+c.t2)/2);
drop table cleaned;

-- updating the rating column by average rating of that area
select location,round(avg(rating),2) average from swiggy
where rating not like '%mins%'
group by location;

update swiggy s 
inner join
(select location,round(avg(rating),2) average from swiggy
where rating not like '%mins%'
group by location) t
on s.location=t.location
set s.rating=t.average
where s.rating like '%mins%';

-- still some values remain, because they are in unique locations, so we substitute rating with average rating of whole dataset
set @average=(select round(avg(rating),2) from swiggy where rating not like '%mins%');
update swiggy set rating=@average where rating like '%mins%';

-- cleaning location column
update swiggy set location='Kandivali East'
where location like '%East%' or location like '%E%';
update swiggy set location='Kandivali West'
where location like '%West%' or location like '%W%';

-- cleaning the offer_percentage column
update swiggy set offer_percentage=0
where offer_above='not_available';

-- finding distinct food types
select distinct food from
(
select *,substring_index(substring_index(food_type,',',c.count),',',-1) as food 
from swiggy
	join (
        select 1+a.N+b.N*10 as count from (
			select 0 as N union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 
			union all select 5 union all select 6 union all select 7 union all select 8 union all select 9) a
		cross join (
			select 0 as N union all select 1 union all select 2 union all select 3 union all select 4 union all select 5 
			union all select 5 union all select 6 union all select 7 union all select 8 union all select 9) b
			order by count desc) c
		on char_length(food_type)-char_length(replace(food_type,',',''))>=c.count-1
) distinct_food_types;