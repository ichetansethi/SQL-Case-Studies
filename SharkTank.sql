select * from sharktank;

load data infile "E:/Users/Downloads/sharktank.csv"
into table sharktank
fields terminated by ','
optionally enclosed by '"'
lines terminated by '\r\n'
ignore 1 rows;

select * from sharktank;

/* To show highest funding domain wise */

select * from
(
select industry, total_deal_amount_in_lacs, 
row_number() over (partition by industry order by total_deal_amount_in_lacs desc) as rnk from sharktank
) t where rnk=1;

/* To find the domain where female to male pitcher ratio >70% */

select * ,(Female/Male)*100 as ratio from
(
select Industry, sum(female_presenters) as 'Female', sum(male_presenters) as 'Male' 
from sharktank group by Industry having sum(female_presenters)>0  and sum(male_presenters)>0
)m where (Female/Male)*100>70;

/* To determine volume of per season sale pitch made, pitches who received offer and pitches that were converted. 
Also show the percentage of pitches converted and percentage of pitches entertained. */

select a.season_number, total,received_offer,(received_offer/total)*100 as received_percent,accepted_offer,(accepted_offer/total)*100 as accepted_percent from
(
select season_number, count(startup_name) as total
from sharktank
group by season_number
) a
inner join
(
select season_number, count(startup_name) as received_offer
from sharktank
where received_offer='Yes'
group by season_number
) b
on a.season_number=b.season_number
inner join
(
select season_number, count(startup_name) as accepted_offer
from sharktank
where accepted_offer='Yes'
group by season_number
) c
on b.season_number=c.season_number;

/* To determine the season with the highest average monthly sales 
and identify the top 5 industries with the highest average monthly sales during that season. */

set @season= (select season_number
from
(
select season_number, round(avg(Monthly_Sales_in_lacs),2) as average_monthly_sales_in_lacs
from sharktank
group by season_number
order by average_monthly_sales_in_lacs desc
limit 1
)s
);

select industry,round(avg(Monthly_Sales_in_lacs),2) as average
from sharktank
where season_number=@season
group by industry
order by average desc
limit 5;

/* To identify industries with consistent increase in funds raised over multiple seasons. 
This requires focusing on industries where data is available across all three seasons. 
Once these industries are pinpointed, analyze the number of pitches made, offers received, 
and offers converted per season within each industry. */

select industry, season_number,sum(total_deal_amount_in_lacs) as sum_total
from sharktank
group by industry,season_number;

with s as 
(
select industry,
max(case when season_number=1 then total_deal_amount_in_lacs end) as season1,
max(case when season_number=2 then total_deal_amount_in_lacs end) as season2,
max(case when season_number=3 then total_deal_amount_in_lacs end) as season3
from sharktank
group by industry
having season3>season2 and season2>season1 and season1 is not null
)

select st.season_number,s.industry,
count(st.Startup_Name) as total,
count(case when st.received_offer='yes' then st.startup_name end) as received,
count(case when st.accepted_offer='yes' then st.startup_name end) as accepted 
from s 
inner join
sharktank st
on st.industry=s.industry
group by st.season_number,s.industry;

/* To know in how much time, a shark's investment will return, so shark will enter the name of the startup’s name
and the based on the total deal and equity given it will calculate the time in years in which their principal amount will return. */

delimiter //
create procedure TOT( in startup varchar(100))
begin
   case 
      when (select Accepted_offer ='No' from sharktank where startup_name = startup)
	        then  select 'Turn Over time cannot be calculated';
	 when (select Accepted_offer ='yes' and Yearly_Revenue_in_lacs = 'Not Mentioned' from sharktank where startup_name= startup)
           then select 'Previous data is not available';
	 else
         select `startup_name`,`Yearly_Revenue_in_lacs`,`Total_Deal_Amount_in_lacssharktank`,`Total_Deal_Equity_percent`, 
         `Total_Deal_Amount_in_lacs`/((`Total_Deal_Equity_percent`/100)*`Total_Deal_Amount_in_lacs`) as 'years'
		 from sharktank where Startup_Name= startup;
	
    end case;
end
//
DELIMITER ;

delimiter //
create procedure tot(in startup varchar(100))
begin
	case
		when (select accepted_offer='No' from sharktank where startup_name=startup)
			then select 'TOT cannot be calculated because startup did not accept the offer';
        when (select accepted_offer='Yes' and Yearly_Revenue_in_lacs='Not Mentioned' from sharktank where startup_name=startup)
			then select 'TOT cannot be calculated as past data is not available';
		else
			select startup_name,Yearly_Revenue_in_lacs,total_deal_amount_in_lacs,Total_Deal_Equity_percent,total_deal_amount_in_lacs/((Total_Deal_Equity_percent/100)*Yearly_Revenue_in_lacs) as years
		 from sharktank where Startup_Name= startup;
end case;
end
// delimiter

call tot('BluePineFoods')
-- any startup name can be used in the quotes where procedure is being called.

/* To find out the average investment of each shark into the startups and who has maximum average investment. */

select sharkname, round(avg(investment),2)  as average 
from
(
SELECT Namita_Investment_Amount_in_lacs AS investment, 'Namita' AS sharkname 
FROM sharktank 
WHERE Namita_Investment_Amount_in_lacs > 0
union all
SELECT Vineeta_Investment_Amount_in_lacs AS investment, 'Vineeta' AS sharkname 
FROM sharktank 
WHERE Vineeta_Investment_Amount_in_lacs > 0
union all
SELECT Anupam_Investment_Amount_in_lacs AS investment, 'Anupam' AS sharkname 
FROM sharktank 
WHERE Anupam_Investment_Amount_in_lacs > 0
union all
SELECT Aman_Investment_Amount_in_lacs AS investment, 'Aman' AS sharkname 
FROM sharktank 
WHERE Aman_Investment_Amount_in_lacs > 0
union all
SELECT Peyush_Investment_Amount_in_lacs AS investment, 'Peyush' AS sharkname 
FROM sharktank 
WHERE Peyush_Investment_Amount_in_lacs > 0
union all
SELECT Amit_Investment_Amount_in_lacs AS investment, 'Amit' AS sharkname 
FROM sharktank 
WHERE Amit_Investment_Amount_in_lacs > 0
union all
SELECT Ashneer_Investment_Amount_in_lacs AS investment, 'Ashneer' AS sharkname 
FROM sharktank 
WHERE Ashneer_Investment_Amount_in_lacs > 0
)k group by sharkname

/* To provide detailed insights into the total investment made by each shark across different industries during the specific season
and calculate the percentage of their investment in each sector relative to the total investment in that year. */

DELIMITER //
create PROCEDURE getseasoninvestment(IN season INT, IN sharkname VARCHAR(100))
BEGIN
    CASE 
        WHEN sharkname = 'Namita' THEN
            set @total = (select sum(Namita_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
            SELECT Industry, sum(Namita_Investment_Amount_in_lacs) as sum ,(sum(Namita_Investment_Amount_in_lacs)/@total)*100 as Percent FROM sharktank WHERE season_Number = season AND Namita_Investment_Amount_in_lacs > 0
            group by industry;
        WHEN sharkname = 'Vineeta' THEN
			set @total = (select sum(Vineeta_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
            SELECT industry,sum(Vineeta_Investment_Amount_in_lacs) as sum,(sum(Vineeta_Investment_Amount_in_lacs)/@total)*100 as Percent FROM sharktank WHERE season_Number = season AND Vineeta_Investment_Amount_in_lacs > 0
            group by industry;
        WHEN sharkname = 'Anupam' THEN
			set @total = (select sum(Anupam_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
            SELECT industry,sum(Anupam_Investment_Amount_in_lacs) as sum,(sum(Anupam_Investment_Amount_in_lacs)/@total)*100 as Percent FROM sharktank WHERE season_Number = season AND Anupam_Investment_Amount_in_lacs > 0
            group by Industry;
        WHEN sharkname = 'Aman' THEN
			set @total = (select sum(Aman_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
            SELECT industry,sum(Aman_Investment_Amount_in_lacs) as sum,(sum(Aman_Investment_Amount_in_lacs)/@total)*100 as Percent  FROM sharktank WHERE season_Number = season AND Aman_Investment_Amount_in_lacs > 0
             group by Industry;
        WHEN sharkname = 'Peyush' THEN
			set @total = (select sum(Peyush_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
             SELECT industry,sum(Peyush_Investment_Amount_in_lacs) as sum,(sum(Peyush_Investment_Amount_in_lacs)/@total)*100 as Percent FROM sharktank WHERE season_Number = season AND Peyush_Investment_Amount_in_lacs > 0
             group by Industry;
        WHEN sharkname = 'Amit' THEN
			set @total = (select sum(Amit_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
              SELECT industry,sum(Amit_Investment_Amount_in_lacs) as sum,(sum(Amit_Investment_Amount_in_lacs)/@total)*100 as Percent FROM sharktank WHERE season_Number = season AND Amit_Investment_Amount_in_lacs > 0
             group by Industry;
        WHEN sharkname = 'Ashneer' THEN
			set @total = (select sum(Ashneer_Investment_Amount_in_lacs) from sharktank where Season_Number= season );
            SELECT industry,sum(Ashneer_Investment_Amount_in_lacs) as sum,(sum(Ashneer_Investment_Amount_in_lacs)/@total)*100 as Percent FROM sharktank WHERE season_Number = season AND Ashneer_Investment_Amount_in_lacs > 0
             group by Industry;
        ELSE
            SELECT 'Invalid shark name';
    END CASE;
    
END //
DELIMITER ;

call getseasoninvestment(2, 'Ashneer');
-- any shark name can be added in above procedure

/* To explore which shark has most diversified portfolio across various industries. */

select sharkname, 
count(distinct industry) as 'unique industy',
count(distinct concat(pitchers_city,' ,', pitchers_state)) as 'unique locations' 
from 
(
		SELECT Industry, Pitchers_City, Pitchers_State, 'Namita'  as sharkname from sharktank where  Namita_Investment_Amount_in_lacs > 0
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Vineeta'  as sharkname from sharktank where Vineeta_Investment_Amount_in_lacs > 0
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Anupam'  as sharkname from sharktank where  Anupam_Investment_Amount_in_lacs > 0 
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Aman'  as sharkname from sharktank where Aman_Investment_Amount_in_lacs > 0
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Peyush'  as sharkname from sharktank where Peyush_Investment_Amount_in_lacs > 0
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Amit'  as sharkname from sharktank where Amit_Investment_Amount_in_lacs > 0
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Anupam'  as sharkname from sharktank where  `Anupam_Investment_Amount_in_lakhs` > 0 
		union all
		SELECT Industry, Pitchers_City, Pitchers_State, 'Ashneer'  as sharkname from sharktank where `Ashneer_Investment_Amount_in_lakhs` > 0
)t  
group by sharkname 
order by  'unique industry' desc ,'unique location' desc;