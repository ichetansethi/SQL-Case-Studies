SELECT * FROM salaries;

/*To pinpoint countries who give full remote work, 
for the title 'managers’ paying salaries exceeding $90,000 USD */

select distinct company_location from salaries 
where job_title like '%Manager%' and salary_in_usd > '90,000'and remote_ratio='100';

/* To identify top 5 countries having greatest count of large (company size) number of companies. */

select company_location, count(*) as country from 
(
select * from salaries 
where experience_level='EN' and company_size='L'
)t group by company_location
order by country desc limit 5;

/* To calculate the percentage of employees who enjoy fully remote roles with salaries exceeding $100,000 USD */

set @count= (SELECT COUNT(*) FROM salaries WHERE salary > 100000 AND remote_ratio = 100);
set @total= (SELECT COUNT(*) FROM salaries WHERE salary > 100000);
set @percentage= round(((select @count)/(select @total))*100,2);
select @percentage as 'Percentage';

/* To identify the locations where average salaries exceed the average salary for that job title in market. */

select t.job_title, m.company_location, average_salary, average_country_salary from
(
select job_title, avg(salary_in_usd) as 'average_salary'
from salaries group by job_title
) t
inner join
(
select company_location, job_title, avg(salary_in_usd) as 'average_country_salary'
from salaries group by job_title, company_location
) m
on t.job_title=m.job_title
where average_country_salary>average_salary;

/*To Find out for each job title which country pays the maximum average salary. */

select job_title, company_location from
(
select *, dense_rank() over (partition by job_title order by avg_sal desc) as rankbysalary from
(
select job_title, company_location, avg(salary_in_usd) avg_sal
from salaries
group by company_location, job_title
)t
)m
where rankbysalary=1;

/* To pinpoint locations where the average salary has consistently increased over the past few years 
(Countries where data is available for 3 years only(present year and past two years) */

with appraisal as
(
select * from salaries
where company_location in
(
select company_location from
(
select company_location, count(distinct work_year) count
from salaries 
where work_year>=year(current_date())-2
group by company_location
having count=3
)t
)
)

select company_location,
max(case when work_year=2022 then average end) as avg_salary_2022,
max(case when work_year=2023 then average end) as avg_salary_2023,
max(case when work_year=2024 then average end) as avg_salary_2024
from
(
select company_location, work_year, avg(salary_in_usd) as average
from appraisal
group by company_location, work_year
)q group by company_location
having avg_salary_2024 >avg_salary_2023 and avg_salary_2023> avg_salary_2022;

/* to determine the percentage of fully remote work for each experience level in 2021 
and compare it with the corresponding figures for 2024, 
highlighting any significant increases or decreases in remote work adoption over the years. */ 

select * from
(
select *, (count_remote/count_total)*100 as count_21 from
(
select a.experience_level, count_total, count_remote from
(
select experience_level, count(*) count_total from salaries
where work_year='2021'
group by experience_level
)a
inner join
(
select experience_level, count(*) count_remote from salaries
where work_year='2021' and remote_ratio=100
group by experience_level
)b
on a.experience_level=b.experience_level
)t
)m
inner join
(
select *, (count_remote/count_total)*100 as count_24 from
(
select a.experience_level, count_total, count_remote from
(
select experience_level, count(*) count_total from salaries
where work_year='2024'
group by experience_level
)a
inner join
(
select experience_level, count(*) count_remote from salaries
where work_year='2024' and remote_ratio=100
group by experience_level
)b
on a.experience_level=b.experience_level
)t
)s
on s.experience_level=m.experience_level;

/* To calculate the average salary increase percentage for each experience level and job title between the years 2023 and 2024 */

select a.job_title, a.experience_level, sal_2023, sal_2024, round((((sal_2024-sal_2023)/sal_2023)*100),2) as salary_change
from
(
select job_title, experience_level, avg(salary_in_usd) sal_2023
from salaries
where work_year=2023
group by job_title, experience_level
)a
inner join
(
select job_title, experience_level, avg(salary_in_usd) sal_2024
from salaries
where work_year=2024
group by job_title, experience_level
)b
on a.job_title=b.job_title and a.experience_level=b.experience_level
group by a.job_title, a.experience_level;

/* To implement a security measure where employees in different experience level (e.g. Entry Level, Senior level etc.) can only access details relevant to their respective experience level, 
ensuring data confidentiality and minimizing the risk of unauthorized access. */
-- DCL: Grant and Revoke

create user 'entry_level'@'%' identified by 'EN';
create user 'junior_mid_level'@'%' identified by 'MI';
create user 'intermediate_senior_level'@'%' identified by 'SE';
create user 'expert_executive_level'@'%' identified by 'EX';
create view entry_level as
(
select * from salaries where experience_level='EN'
);
grant select on case_studies.entry_level TO 'entry_level'@'%';
create view junior_mid_level as
(
select * from salaries where experience_level='MI'
);
grant select on case_studies.entry_level TO 'junior_mid_level'@'%';
create view intermediate_senior_level as
(
select * from salaries where experience_level='SE'
);
grant select on case_studies.entry_level TO 'intermediate_senior_level'@'%';
create view expert_executive_level as
(
select * from salaries where experience_level='EX'
);
grant select on case_studies.entry_level TO 'expert_executive_level'@'%';

/*  to guide an employee to which domain they should switch to, based on the input they provided, 
so that they can now update their knowledge as per the suggestion which should be based on average salary. */

DELIMITER //
create PROCEDURE GetAverageSalary(IN exp_lev VARCHAR(2), IN emp_type VARCHAR(3), IN comp_loc VARCHAR(2), IN comp_size VARCHAR(2))
BEGIN
    SELECT job_title, experience_level, company_location, company_size, employment_type, ROUND(AVG(salary), 2) AS avg_salary 
    FROM salaries 
    WHERE experience_level = exp_lev AND company_location = comp_loc AND company_size = comp_size AND employment_type = emp_type 
    GROUP BY experience_level, employment_type, company_location, company_size, job_title order by avg_salary desc ;
END//
DELIMITER ;
-- Delimiter  By doing this, you're telling MySQL that statements within the block should be parsed as a single unit until the custom delimiter is encountered.

call GetAverageSalary('EN','FT','AU','M');

drop procedure Getaveragesalary;