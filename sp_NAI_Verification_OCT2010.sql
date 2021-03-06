USE [STG_MART_NDE]
GO
/****** Object:  StoredProcedure [dbo].[rptGET_NAI_GRID]    Script Date: 1/17/2017 2:05:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[rptGET_NAI_GRID]
(
	@DISTRICT_CODE char(7),	
	@SCHOOL_YEAR datetime
)

AS

DECLARE	@DISTRICT_KEY INT
SELECT  @DISTRICT_KEY = DISTRICT_KEY
FROM    STG_MART.SCHOLWHS.DISTRICT
WHERE   DISTRICT_CODE = @DISTRICT_CODE

/*  Verification Report for NAI  */

select
student_id,
student_last_nm,
student_first_nm,
student_mid_init,
fact.district_key,
district.district_code,
fact.school_year,
item.item_desc as grade,
fact.[percent] as reading_score,
case when fact.[percent] < 25 then 'Q1'
		when fact.[percent] >= 25 and fact.[percent] < 50 then 'Q2'
		when fact.[percent] >= 50 and fact.[percent] < 75 then 'Q3'
		when fact.[percent] >= 75 then 'Q4'
else 'Not Included'
end as 'reading_quartile',
fact.LOCAL_STANINE as mathematics_score,
case when fact.LOCAL_STANINE < 25 then 'Q1'
		when fact.LOCAL_STANINE >= 25 and fact.LOCAL_STANINE < 50 then 'Q2'
		when fact.LOCAL_STANINE >= 50 and fact.LOCAL_STANINE < 75 then 'Q3'
		when fact.LOCAL_STANINE >= 75 then 'Q4'
else 'Not Included'
end as 'mathematics_quartile',
info.test_desc as NAI
into #verify_nai
from stg_mart.SCHOLWHS.ASSESSMENT_FACT as fact
inner join stg_mart.SCHOLWHS.STUDENT as student on
	fact.student_key = student.student_key and
	fact.school_year = student.school_year and
	fact.district_key = student.district_key
inner join stg_mart.SCHOLWHS.ASSESSMENT_ITEM as item on
	fact.item_key = item.item_key
inner join stg_mart.SCHOLWHS.ASSESSMENT_INFO as info on
	fact.test_key = info.test_key
inner join stg_mart.scholwhs.district as district on
	fact.district_key = district.district_key
where fact.school_year = @school_year and 
district.district_code = @district_code and 
info.test_desc not in ('STARS','STARS Alternate')


/*  Create a Master Table with NAI and Grade by District and School Code  */

select distinct
district_key,
school_year,
grade,
nai
into #master_nai
from #verify_nai




/*  Create Reading and Mathematics Counts by Quartile  */

select
district_key,
grade,
nai,
reading_quartile,
count(reading_quartile) as reading_quartile_count
into #reading_quartile_count
from #verify_nai
group by district_key,grade,nai,reading_quartile



select
district_key,
grade,
nai,
mathematics_quartile,
count(mathematics_quartile) as mathematics_quartile_count
into #mathematics_quartile_count
from #verify_nai
group by district_key,grade,nai,mathematics_quartile



select
master.District_key,
master.Grade,
master.NAI,
school_year,
subject='Reading',
max(case when reading_quartile='Q1' then reading_quartile_count else ' ' end) as Q1_count,
max(case when reading_quartile='Q2' then reading_quartile_count else ' ' end) as Q2_count,
max(case when reading_quartile='Q3' then reading_quartile_count else ' ' end) as Q3_count,
max(case when reading_quartile='Q4' then reading_quartile_count else ' ' end) as Q4_count,
max(case when reading_quartile='Not Included' then reading_quartile_count else ' ' end) as NI_count
into #master_reading
from #master_nai as master
left join #reading_quartile_count as reading on
	master.district_key = reading.district_key and
	master.grade = reading.grade and
	master.nai = reading.nai
group by master.district_key,master.grade,master.nai,school_year



select
master.District_key,
master.Grade,
master.NAI,
school_year,
subject='Math',
max(case when mathematics_quartile='Q1' then mathematics_quartile_count else ' ' end) as Q1_count,
max(case when mathematics_quartile='Q2' then mathematics_quartile_count else ' ' end) as Q2_count,
max(case when mathematics_quartile='Q3' then mathematics_quartile_count else ' ' end) as Q3_count,
max(case when mathematics_quartile='Q4' then mathematics_quartile_count else ' ' end) as Q4_count,
max(case when mathematics_quartile='Not Included' then mathematics_quartile_count else ' ' end) as NI_count
into #master_math
from #master_nai as master
left join #mathematics_quartile_count as math on
	master.district_key = math.district_key and
	master.grade = math.grade and
	master.nai = math.nai
group by master.district_key,master.grade,master.nai,school_year




/*  Create Quartile Total to create percentages  */

select 
master.district_key,
master.grade,
master.nai,
sum(reading_quartile_count) as reading_quartile_total
into #reading_quartile_total
from #master_nai as master 
left join #reading_quartile_count as reading on
	master.district_key = reading.district_key and
	master.grade = reading.grade and
	master.nai = reading.nai 
group by master.district_key,
master.grade,
master.nai



select 
master.district_key,
master.grade,
master.nai,
sum(mathematics_quartile_count) as mathematics_quartile_total
into #mathematics_quartile_total
from #master_nai as master 
left join #mathematics_quartile_count as math on
	master.district_key = math.district_key and
	master.grade = math.grade and
	master.nai = math.nai
group by master.district_key,
master.grade,
master.nai



select
master.District_key,
master.Grade,
master.NAI,
school_year,
subject,
Q1_count,
Q1_pct=cast(((cast(Q1_count as float))/reading_quartile_total)*100 as decimal(10,2)),
Q2_count,
Q2_pct=cast(((cast(Q2_count as float))/reading_quartile_total)*100 as decimal(10,2)),
Q3_count,
Q3_pct=cast(((cast(Q3_count as float))/reading_quartile_total)*100 as decimal(10,2)),
Q4_count,
Q4_pct=cast(((cast(Q4_count as float))/reading_quartile_total)*100 as decimal(10,2)),
NI_count,
NI_pct=cast(((cast(NI_count as float))/reading_quartile_total)*100 as decimal(10,2))
into #final_master_reading
from #master_reading as master
left join #reading_quartile_total as read_total on
	master.district_key = read_total.district_key and
	master.grade = read_total.grade and
	master.nai = read_total.nai


select
master.District_key,
master.Grade,
master.NAI,
school_year,
subject,
Q1_count,
Q1_pct=cast(((cast(Q1_count as float))/mathematics_quartile_total)*100 as decimal(10,2)),
Q2_count,
Q2_pct=cast(((cast(Q2_count as float))/mathematics_quartile_total)*100 as decimal(10,2)),
Q3_count,
Q3_pct=cast(((cast(Q3_count as float))/mathematics_quartile_total)*100 as decimal(10,2)),
Q4_count,
Q4_pct=cast(((cast(Q4_count as float))/mathematics_quartile_total)*100 as decimal(10,2)),
NI_count,
NI_pct=cast(((cast(NI_count as float))/mathematics_quartile_total)*100 as decimal(10,2))
into #final_master_math
from #master_math as master
left join #mathematics_quartile_total as math_total on
	master.district_key = math_total.district_key and
	master.grade = math_total.grade and
	master.nai = math_total.nai




/*  Create final table for output  */
select 
district_code,
district_name + '  ' + '[' + district_code + ']' as school_building,
convert(char(10),school_year,126)as school_year,
ltrim(str(year(@school_year)-1))+'-'+ltrim(str(year(@school_year))) as datayears,
grade,
nai,
nai + ' ' +'GRADE'+ grade as NAI_GRADE,
subject,
q1_count,
q1_pct,
q2_count,
q2_pct,
q3_count,
q3_pct,
q4_count,
q4_pct,
NI_count,
NI_pct
from #final_master_reading as reading
inner join stg_mart.scholwhs.district as district on
	reading.district_key = district.district_key
UNION ALL
select 
district_code,
district_name + '  ' + '[' + district_code + ']' as school_building,
convert(char(10),school_year,126)as school_year,
ltrim(str(year(@school_year)-1))+'-'+ltrim(str(year(@school_year))) as datayears,
grade,
nai,
nai + ' ' +'GRADE'+ grade as NAI_GRADE,
subject,
q1_count,
q1_pct,
q2_count,
q2_pct,
q3_count,
q3_pct,
q4_count,
q4_pct,
NI_count,
NI_pct
from #final_master_math as math
inner join stg_mart.scholwhs.district as district on
	math.district_key = district.district_key
order by district_code,nai,grade,subject



drop table #master_nai
drop table #mathematics_quartile_total
drop table #mathematics_quartile_count
drop table #reading_quartile_total
drop table #reading_quartile_count
drop table #master_math
drop table #final_master_math
drop table #master_reading
drop table #final_master_reading
drop table #verify_nai
