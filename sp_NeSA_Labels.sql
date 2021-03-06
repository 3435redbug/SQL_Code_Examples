USE [STG_MART_NDE]
GO
/****** Object:  StoredProcedure [dbo].[rptGET_NeSA_LABELS]    Script Date: 1/17/2017 2:06:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[rptGET_NeSA_LABELS]
(
	
	@DISTRICT_CODE char(7),
	@SCHOOL_YEAR datetime
)

AS

/****	
		ADDED CODE SO RACE/ETHNICITY HAS BEEN ADDRESSED FOR THE 2010-2011
		SCHOOL YEAR.  SEE JILL'S EMAIL FROM 8/10/2010 IN RACE/ETHNICITY
		FOLDER.
		MRM 2010/08/27
		
		ADDED CODE TO LOOK AT THE GRADUATION YEAR ASSIGNED IN ORDER TO DETERMINE
		WHICH STUDENTS ARE TO BE TESTED AS "11TH" GRADERS.  GRAD_YEAR_CODE = 2012
		FOR THE 2011 NESA TESTING. 
		@GRAD_YEAR_11 IS DEFINED.
		MRM 2010/10/08
		
		ADDED CODE TO ACCOUNT FOR YEAR-END SPECIAL ED SNAPSHOT SUBMISSIONS.
		MRM 2010/11/17
		
		Modified: 09/20/2013 KBR <Included 208, 209 (209 - New Enrollment Code starting 2013-2014 School Year)>
		Modified: 12/02/2016 KBR -- Included 210, 211, 212 Instead of 203, 204 starting 2016-2017 School Year
						    -- 210 Completer: Graduated with a regular or advanced Diploma
						    -- 211 Completer: with an Alternative Modified Diploma
							-- 212 Noncompleter
****/

DECLARE	@DISTRICT_KEY INT
SELECT  @DISTRICT_KEY = DISTRICT_KEY
FROM    STG_MART.SCHOLWHS.DISTRICT
WHERE   DISTRICT_CODE = @DISTRICT_CODE



DECLARE	@EFFECT_DATE DATETIME
SET	@EFFECT_DATE = @SCHOOL_YEAR

DECLARE @SNAPSHOT_DATE VARCHAR(10)
SET @SNAPSHOT_DATE = CAST((YEAR(@SCHOOL_YEAR)-1)AS VARCHAR) + '-10-01'

DECLARE @GRAD_YEAR VARCHAR(4)
SET @GRAD_YEAR = YEAR(@SCHOOL_YEAR) + 1

DECLARE @EXIT_DATE VARCHAR(10)
SET @EXIT_DATE = CAST(YEAR(@SCHOOL_YEAR) AS VARCHAR) + '-02-02'

DECLARE @TABLETYPE VARCHAR(50)
SET @TABLETYPE = 'NeSA READING'

	
	DECLARE @LOCK_DATE DATETIME
    SET @LOCK_DATE = (select lock_date from STG_MART_NDE.DBO.TABLE_LOCK_DATE
            where  TABLE_TYPE = @tabletype and school_year = @school_year)

-- check to see that a record exists for the year requested
-- if a record does not exist, assume live processing
IF (SELECT COUNT(*) FROM STG_MART_NDE.DBO.TABLE_LOCK_DATE
      WHERE TABLE_TYPE = @TABLETYPE AND SCHOOL_YEAR = @SCHOOL_YEAR) = 1
      
	BEGIN --SELECT COUNT(*) ... = 1

      
	-- check to see if the lock date is less than the current date
	-- for the given school year.  If it is, frozen processing.
	IF @LOCK_DATE < GETDATE()
            
            
            BEGIN  /*  FROZEN FILE PROCESSING  */ --@LOCK_DATE<GETDATE()
			PRINT 'FROZEN FILE PROCESSING'
			SELECT
			STUDENT_FIRST_NAME AS stud_first_nm,
			STUDENT_MIDDLE_INITIAL AS stud_mid_init, 
			STUDENT_LAST_NAME AS stud_last_nm,
			STUDENT_DOB_YEAR + '-' + STUDENT_DOB_MONTH + '-' + STUDENT_DOB_DAY AS stud_dob,
			STUDENT_GENDER_CODE AS STUDENT_GENDER,
			STUDENT_GRADE AS CURR_GRADE_LVL,
			NDE_STUDENT_ID AS STUDENT_ID,
			STUDENT_KEY = ' ', 
			SUBSTRING(A.DISTRICT_NUMBER,1,7) AS DISTRICT_CODE,
			b.district_name,
			RIGHT(A.SCHOOL_NUMBER,3) AS LOCATION_ID,
			c.location_name,
			ETHNICITY AS ETHNIC_CODE,
			--FOOD_PROGRAM_ELIGIBILITY = (CASE WHEN A.FOOD_PROGRAM_ELIGIBILITY = '0' THEN 'No' ELSE 'Yes' END),
			LEP_ELL_ELIGIBILITY = (CASE WHEN A.LEP_ELL_ELIGIBILITY = '1' THEN 'Yes' ELSE 'No' END),
			SPECIAL_ED = (CASE WHEN A.SPECIAL_ED = '1' THEN 'Yes' ELSE 'No' END),
			AA_READING = (CASE WHEN A.AA_READING = '1' THEN 'Yes'
					WHEN A.AA_READING = '2' THEN 'No' ELSE ' ' END),
			AA_MATH = (CASE WHEN A.AA_MATH = '1' THEN 'Yes'
					WHEN A.AA_MATH = '2' THEN 'No' ELSE ' ' END),
			AA_SCIENCE = (CASE WHEN A.AA_SCIENCE = '1' THEN 'Yes'
					WHEN A.AA_SCIENCE = '2' THEN 'No' ELSE ' ' END),
			A.SCHOOL_YEAR,
			LOCK_DATE = @LOCK_DATE
			FROM STG_MART_NDE.dbo.NeSA_LABELS AS A
			INNER JOIN STG_MART.SCHOLWHS.DISTRICT AS B ON
				'31'+ LEFT(A.DISTRICT_NUMBER,2) + SUBSTRING(A.DISTRICT_NUMBER,4,4) = B.DISTRICT_KEY
			INNER JOIN STG_MART.SCHOLWHS.LOCATION AS C ON
				'31'+ LEFT(A.DISTRICT_NUMBER,2) + SUBSTRING(A.DISTRICT_NUMBER,4,4) = C.DISTRICT_KEY AND
				RIGHT(A.SCHOOL_NUMBER,3) = C.LOCATION_ID
			WHERE
					DISTRICT_NUMBER = @DISTRICT_CODE + '-000' AND
					SCHOOL_YEAR = @SCHOOL_YEAR
           
            
            END --@LOCK_DATE<GETDATE()
            
        ELSE

			BEGIN --@LOCK_DATE>=GETDATE()
				GOTO LiveProcessing
			END --@LOCK_DATE>=GETDATE()
		END --SELECT COUNT(*) ... = 1

      
ELSE

LiveProcessing:

BEGIN --SELECT COUNT(*) ... <> 1

/* Selecting effect date - maximum  */
SELECT STUDENT_KEY, DISTRICT_KEY, SCHOOL_YEAR, MAX(EFFECT_DATE) AS EFFECT_DATE
INTO #MAX_DATE_TEMP
FROM STG_MART.SCHOLWHS.SCHOOL_ENROLL
WHERE	EFFECT_DATE < @EFFECT_DATE AND
		SCHOOL_YEAR = @SCHOOL_YEAR AND
		DISTRICT_KEY = @DISTRICT_KEY
GROUP BY STUDENT_KEY, DISTRICT_KEY, SCHOOL_YEAR


/* Selecting student*/
SELECT DISTINCT A.STUDENT_KEY, A.DISTRICT_KEY, A.SCHOOL_YEAR
INTO #STUDENT_TEMP
FROM #MAX_DATE_TEMP AS A
INNER JOIN STG_MART.SCHOLWHS.SCHOOL_ENROLL AS C ON
	A.STUDENT_KEY = C.STUDENT_KEY AND
	A.EFFECT_DATE = C.EFFECT_DATE AND
	A.SCHOOL_YEAR = C.SCHOOL_YEAR
INNER JOIN STG_MART.SCHOLWHS.ENROLL_CODES AS B ON
	C.ENROLL_KEY = B.ENROLL_KEY
WHERE B.ENROLL_CODE IN ('100', '101', '102', '103', '200') 



/*  SELECT STUDENTS WHO ARE CONSIDERED "11TH" GRADE DUE TO GRADUATION COHORT  */

if @SCHOOL_YEAR < '2017-06-30'
	begin
		SELECT STUDENT_ID,GRAD_YEAR
		INTO #GRADE_11
		FROM STG_MART_NDE.dbo.COHORT_STUDENT_COHORT
		WHERE COHORT_YEAR_INDICATOR='1'
		AND GRAD_YEAR=@GRAD_YEAR
	end


SELECT A.SCHOOL_YEAR,
	UPPER(A.STUDENT_FIRST_NM)as stud_first_nm,
	UPPER(A.STUDENT_MID_INIT)as stud_mid_init, 
	UPPER(A.STUDENT_LAST_NM)as stud_last_nm,
	convert(char(10),STUD_BIRTHDATE,126)as stud_dob,
	student_gender = substring(A.STUDENT_GENDER,1,1),
	A.CURR_GRADE_LVL,
	A.STUDENT_ID,
	A.STUDENT_KEY, 
	B.DISTRICT_CODE,
	b.district_name,
	C.LOCATION_ID,
	c.location_name,
	ETHNIC_CODE = (CASE WHEN A.SCHOOL_YEAR <= '2010-06-30' THEN A.ETHNIC_CODE
						ELSE RACE.[REPORTING_RACE_CODE] END),
--	FOOD_PROGRAM_ELIGIBILITY = (CASE WHEN A.FOOD_PGM_ELIG_CD = '0' THEN 'No' ELSE 'Yes' END),
	LEP_ELL_ELIGIBILITY = A.LEP_ELIGIBILITY,
	SPECIAL_ED = (CASE WHEN A.SCHOOL_YEAR <= '2010-06-30' THEN A.SPECIAL_ED_CODE
					   ELSE (CASE WHEN (D.STUDENT_KEY = E.STUDENT_KEY and (exit_date is null OR EXIT_DATE >= @EXIT_DATE)) THEN 'Yes'
							 	  WHEN (D.STUDENT_KEY = E.STUDENT_KEY and exit_date < @EXIT_DATE) THEN 'No'
								  ELSE 'No' END)
					   END),
	E.SNAPSHOT_DATE,
	E.EXIT_DATE,
	AA_READING = CASE WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' AND (exit_date is null OR EXIT_DATE >= @EXIT_DATE)) THEN 'Yes'
					  WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' AND E.EXIT_DATE < @EXIT_DATE) THEN 'No'
					  ELSE 'No' END,
	AA_MATH = CASE WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' and (exit_date is null OR EXIT_DATE >= @EXIT_DATE)) THEN 'Yes'
				   WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' and E.EXIT_DATE < @EXIT_DATE) THEN 'No'
				   ELSE 'No' END,
	LOCK_DATE = @LOCK_DATE
INTO #NeSA_LABELS
FROM STG_MART.SCHOLWHS.STUDENT AS A
INNER JOIN STG_MART.SCHOLWHS.DISTRICT AS B ON
		A.DISTRICT_KEY = B.DISTRICT_KEY
INNER JOIN STG_MART.SCHOLWHS.LOCATION AS C ON
		A.LOCATION_KEY = C.LOCATION_KEY
INNER JOIN #STUDENT_TEMP AS D ON
		A.STUDENT_KEY = D.STUDENT_KEY AND
		A.DISTRICT_KEY = D.DISTRICT_KEY
LEFT JOIN [STG_MART_NDE].[dbo].[REPORTING_RACE_LOOKUP] as RACE ON
        A.[RPTG_RACE_ETHNICITY_DESC] = RACE.[RPTG_RACE_ETHNICITY_DESC]
LEFT JOIN STG_MART.SCHOLWHS.SPECIAL_ED_SNAP AS E ON
		A.STUDENT_KEY = E.STUDENT_KEY AND
		A.SCHOOL_YEAR = E.SCHOOL_YEAR
WHERE	A.SCHOOL_YEAR = @SCHOOL_YEAR and
		A.CURR_GRADE_LVL IN ('03', '04', '05','06','07','08')AND
		A.DISTRICT_KEY = @DISTRICT_KEY AND
		A.FTE_PERCENT > 50

if @SCHOOL_YEAR < '2017-06-30'

	begin
			insert into #NeSA_LABELS
			SELECT A.SCHOOL_YEAR,
			UPPER(A.STUDENT_FIRST_NM)as stud_first_nm,
			UPPER(A.STUDENT_MID_INIT)as stud_mid_init, 
			UPPER(A.STUDENT_LAST_NM)as stud_last_nm,
			convert(char(10),STUD_BIRTHDATE,126)as stud_dob,
			student_gender = substring(A.STUDENT_GENDER,1,1),
			CURR_GRADE_LVL=@GRAD_YEAR,
			A.STUDENT_ID,
			A.STUDENT_KEY, 
			B.DISTRICT_CODE,
			b.district_name,
			C.LOCATION_ID,
			c.location_name,
			ETHNIC_CODE = (CASE WHEN A.SCHOOL_YEAR <= '2010-06-30' THEN A.ETHNIC_CODE
								ELSE RACE.[REPORTING_RACE_CODE] END),
		--	FOOD_PROGRAM_ELIGIBILITY = (CASE WHEN A.FOOD_PGM_ELIG_CD = '0' THEN 'No' ELSE 'Yes' END),
			LEP_ELL_ELIGIBILITY = A.LEP_ELIGIBILITY,
			SPECIAL_ED = (CASE WHEN A.SCHOOL_YEAR <= '2010-06-30' THEN A.SPECIAL_ED_CODE
							   ELSE (CASE WHEN (D.STUDENT_KEY = E.STUDENT_KEY and (exit_date is null OR EXIT_DATE >= @EXIT_DATE)) THEN 'Yes'
							 			  WHEN (D.STUDENT_KEY = E.STUDENT_KEY and exit_date < @EXIT_DATE) THEN 'No'
										  ELSE 'No' END)
							   END),
			E.SNAPSHOT_DATE,
			E.EXIT_DATE,
			AA_READING = CASE WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' AND (exit_date is null OR EXIT_DATE >= @EXIT_DATE)) THEN 'Yes'
							  WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' AND E.EXIT_DATE < @EXIT_DATE) THEN 'No'
							  ELSE 'No' END,
			AA_MATH = CASE WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' and (exit_date is null OR EXIT_DATE >= @EXIT_DATE)) THEN 'Yes'
						   WHEN (D.STUDENT_KEY = E.STUDENT_KEY AND E.ALT_ASSESSMENT = 'YES' and E.EXIT_DATE < @EXIT_DATE) THEN 'No'
						   ELSE 'No' END,
			LOCK_DATE = @LOCK_DATE
		FROM STG_MART.SCHOLWHS.STUDENT AS A
		INNER JOIN STG_MART.SCHOLWHS.DISTRICT AS B ON
				A.DISTRICT_KEY = B.DISTRICT_KEY
		INNER JOIN STG_MART.SCHOLWHS.LOCATION AS C ON
				A.LOCATION_KEY = C.LOCATION_KEY
		INNER JOIN #STUDENT_TEMP AS D ON
				A.STUDENT_KEY = D.STUDENT_KEY AND
				A.DISTRICT_KEY = D.DISTRICT_KEY
		LEFT JOIN [STG_MART_NDE].[dbo].[REPORTING_RACE_LOOKUP] as RACE ON
				A.[RPTG_RACE_ETHNICITY_DESC] = RACE.[RPTG_RACE_ETHNICITY_DESC]
		LEFT JOIN STG_MART.SCHOLWHS.SPECIAL_ED_SNAP AS E ON
				A.STUDENT_KEY = E.STUDENT_KEY AND
				A.SCHOOL_YEAR = E.SCHOOL_YEAR
		INNER JOIN #GRADE_11 AS F ON
				A.STUDENT_ID = F.STUDENT_ID
		WHERE
			A.SCHOOL_YEAR = @SCHOOL_YEAR and
			A.DISTRICT_KEY = @DISTRICT_KEY AND
			a.FTE_PERCENT > 50
	end



UPDATE #NeSA_LABELS
SET LOCK_DATE = '1900-01-01'


DELETE FROM #NeSA_LABELS
WHERE STUDENT_KEY IN
		(SELECT A.STUDENT_KEY 
			FROM #MAX_DATE_TEMP AS A
			INNER JOIN STG_MART.SCHOLWHS.SCHOOL_ENROLL AS C ON
				A.STUDENT_KEY = C.STUDENT_KEY AND
				A.EFFECT_DATE = C.EFFECT_DATE
			INNER JOIN STG_MART.SCHOLWHS.ENROLL_CODES AS B ON
				C.ENROLL_KEY = B.ENROLL_KEY
			--WHERE B.ENROLL_CODE IN ('201', '202', '203', '204', '205', '206', '208', '209')) -- Included 208, 209 09/20/2013 
			WHERE B.ENROLL_CODE IN ('201', '202', '203', '204', '210', '211', '212', '205', '206', '208', '209')) -- Included 210, 211, 212 12/02/16  


DELETE FROM #NESA_LABELS
WHERE SNAPSHOT_DATE=@SNAPSHOT_DATE
	AND STUDENT_KEY IN (SELECT STUDENT_KEY FROM #NESA_LABELS
						GROUP BY STUDENT_KEY
						HAVING COUNT(STUDENT_KEY) > 1)





SELECT 
SCHOOL_YEAR,
STUD_FIRST_NM,
STUD_MID_INIT, 
STUD_LAST_NM,
STUD_DOB,
STUDENT_GENDER,
CURR_GRADE_LVL,
STUDENT_ID,
STUDENT_KEY,
DISTRICT_NAME,
DISTRICT_CODE,
LOCATION_NAME,
LOCATION_ID,
ETHNIC_CODE,
LEP_ELL_ELIGIBILITY,
SPECIAL_ED,
SNAPSHOT_DATE,
EXIT_DATE,
AA_READING,
AA_MATH,
LOCK_DATE
FROM #NeSA_LABELS

END --SELECT COUNT(*) ... <> 1