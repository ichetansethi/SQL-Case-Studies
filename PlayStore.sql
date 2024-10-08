select * from playstore;
truncate table playstore;

load data infile "E:/Users/Downloads/playstore.csv"
into table playstore
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

-- CHANGING  COLUMN NAMES
alter table playstore
change column `Content Rating` `Content_Rating` varchar(255);

alter table playstore
change column `Last_Updated` `Last_Updated` date;

alter table playstore
CHANGE COLUMN `Current Ver` `Current_Ver` varchar(255);

alter table playstore
change column `Android Ver` `Android_Ver` varchar(255);

alter table playstore
change column `Type` `PurchaseType` varchar(255);

select * from playstore;

/* To identify the most promising categories (TOP 5) for launching new free apps based on their average ratings */

select Category, round(avg(Rating),2) as average_rating
from playstore
where PurchaseType='Free'
order by average_rating limit 5;


/* To pinpoint the three categories that generate the most revenue from paid apps, 
based on the product of the app price and its number of installations */

select category, round(sum(rev),2) as revenue from
(
select *, (Installs*Price)  as rev from playstore where  type='paid'
)t  group by category 
order by rev desc
limit 3;


/* To calculate the percentage of each category's occurrence in the table, 
to understand the distribution of gaming apps across different categories */

select * , (cnt/(select count(*) from playstore))*100 as 'percentage' from
(
select category , count(category) as 'cnt' from playstore group by category
)m;


/* To recommend whether the company should develop paid or free apps for each category, 
based on the ratings of that category. */

select *, if(Paid>Free, 'Develop Paid Apps','Develop Free Apps') as decision
from
(
select category, round(avg(Rating),2) Paid from playstore
where PurchaseType='Paid'
group by category
)t1
inner join
(
select category, round(avg(Rating),2) Free from playstore
where PurchaseType='Free'
group by category
)t2
on t1.category=t2.category;


/* Suppose you're a database administrator your databases have been hacked and hackers are changing price of certain apps on the database.
It is taking a bit long for IT team to neutralize the hack. However, you as a responsible manager and you don’t want your data to be changed.
Take some measure where the changes in price can be recorded as you can’t stop hackers from making changes. */

create table pricechangelog
(
app varchar(255),
old_price decimal(10,2),
new_price decimal(10,2),
operation_type varchar(255),
operation_time timestamp
);
 create table googleplaystore as
 select * from playstore;
 
DELIMITER //
create trigger price_change_log
after update
on googleplaystore
for each row
begin
	 insert into pricechangelog
	 (app, old_price, new_price, operation_type, operation_time)
	 values 
	 (new.app, old.price, new.price, 'update', current_timestamp());
end;
// DELIMITER;


/* Now you have to insert correct data to be inserted into the database again. */

drop trigger price_change_log;

update play as p1
inner join pricechangelog as p2 
on p1.app = p2.app
set p1.price = p2.old_price;

/* To investigate the correlation between two numeric factors: app ratings and the quantity of reviews. */

set @x = (SELECT ROUND(AVG(rating), 2) FROM playstore);
set @y = (SELECT ROUND(AVG(reviews), 2) FROM playstore);    

with t as 
(
	select  *, round((rat*rat),2) as "var(x)" , round((rev*rev),2) as "var(y)" from
	(
		select  rating , @x, round((rating- @x),2) as 'rat' , reviews , @y, round((reviews-@y),2) as 'rev'from playstore
	)a                                                                                                                        
)

select  @numerator := round(sum(rat*rev),2) , @deno_1 := round(sum(var(x)),2) , @deno_2:= round(sum(var(y)),2) from t;
select round((@numerator)/(sqrt(@deno_1*@deno_2)),2) as corr_coeff;

/* To clean the genres column and make two genres out of it, 
rows that have only one genre will have other column as blank. */

DELIMITER //
CREATE FUNCTION f_name(a VARCHAR(100))
RETURNS VARCHAR(100)
DETERMINISTIC
BEGIN
    SET @l = LOCATE(';', a);

    SET @s = IF(@l > 0, LEFT(a, @l - 1), a);

    RETURN @s;
END//
DELIMITER ;

select f_name('Art & Design;Pretend Play')

DELIMITER //
create function l_name(a varchar(100))
returns varchar(100)
deterministic 
begin
   set @l = locate(';',a);
   set @s = if(@l = 0 ,' ',substring(a,@l+1, length(a)));
   
   return @s;
end //
DELIMITER ;

select app, genres, f_name(genres) as 'gene 1', l_name(genres) as 'gene 2' from playstore
