USE [NESA]
GO
/****** Object:  StoredProcedure [dbo].[USP_POPULATE_PLAS_IDENTIFIED_SCHOOLS]    Script Date: 1/17/2017 1:33:23 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[USP_POPULATE_PLAS_IDENTIFIED_SCHOOLS]
(
        @SCHOOL_YEAR DATETIME = NULL
)
AS

/*  

2010-10-01  MRM  Created job.
2013-10-02 AT Modified code to eliminate needs improvement schools with no final rank(no 3 year data to calculate progress) from tier I and include them as tier iii


*/

IF @SCHOOL_YEAR IS NULL 
    BEGIN
    RAISERROR (
        'Required parameter is not provided.', 16, 1, 
        '"@SCHOOL_YEAR"')
    RETURN 
    END

--DECLARE  @SCHOOL_YEAR DATETIME
--SET @SCHOOL_YEAR = '2012-06-30'

DECLARE @PROCEDURE_NAME [varchar](150),
		@UPDATE_DATE DATETIME


SET @PROCEDURE_NAME = 	'NDESQL04.NESA.dbo.USP_CALCULATE_PLAS'
SET @UPDATE_DATE =		GETDATE()  --DATEDIFF(dd, 0, GETDATE()) 

DECLARE @DATAYEARS VARCHAR(8)
SET @DATAYEARS=(CAST(YEAR(@SCHOOL_YEAR)-1 AS VARCHAR) + CAST(YEAR(@SCHOOL_YEAR) AS VARCHAR))


/**************************************************************/
/********  NEEDS IMPROVEMENT/TITLE I **************************/
/**************************************************************/
/**************************************************************/
/*  SELECT PLAS TIER I - NEEDS IMPROVEMENT/TITLE I            */
/**************************************************************/
-- The 5% of schools with the lowest final rank would be without counting the SIG schools that are already reciving funds.  
--If the 5% calculates to 8 then the Tier I list should include 8 schools that are not receving the funds+any SIG schools that fall within the lowest rank
/*					
*/
--Identify the 5% number using this code
/*					
SELECT ROUND(COUNT(*)*.05,0)
FROM dbo.PLAS_TIERI
WHERE DATAYEARS='20142015'
*/
--11 --2012-11-28 Diane review tier I list, added 4 more schools to Tier I
--16 --2013-09-20 the 5% number is 8 and there are 8 SIG schools and hence we add 8 more to the list.
--13 --2014-11-04 the 5% number is 13 and there are 4 SIG schools and hence we add 4 more to the list.
--19 --2014-11-04 the 5% number is 19 and there are 4 SIG schools and hence we add 4 more to the list.
--19 --2015-11-04 the 5% number is 19 and there are 4 SIG schools and hence we add 4 more to the list.

DECLARE @PLAS_TIERI INT
SET @PLAS_TIERI = 19

SELECT TOP(@PLAS_TIERI)DATAYEARS,AGENCYID,DISTRICT_NAME,
SCHOOL_NAME,GRADE_CODE,TIER='TIER I',REASON='Needs Improvement/Title I',RANKED=final_OPTION_AC_RANK
INTO #PLAS_TIERI_TITLEI
FROM  dbo.PLAS_TIERI
WHERE DATAYEARS= @DATAYEARS AND final_OPTION_AC_RANK IS NOT NULL-- this null checl eliminates the schools with no 3 year progress data from tier I
ORDER BY final_OPTION_AC_RANK ASC



/****************************************************************/
/*  SELECT PLAS TIER III - NEEDS IMPROVEMENT/TITLE I            */
/****************************************************************/

SELECT DATAYEARS,AGENCYID,DISTRICT_NAME,
SCHOOL_NAME,GRADE_CODE,TIER='TIER III',REASON='Needs Improvement/Title I',RANKED=final_OPTION_AC_RANK
INTO #PLAS_TIERIII_TITLEI
FROM  dbo.PLAS_TIERI
WHERE DATAYEARS=@DATAYEARS
AND AGENCYID NOT IN (SELECT AGENCYID FROM #PLAS_TIERI_TITLEI)


/****************************************************************/
/********  ELGIBIGLE BUT NOT SERVED/NON-TITLE I *****************/
/****************************************************************/
/****************************************************************/
/*  SELECT PLAS TIER II - ELGIBIGLE BUT NOT SERVED/NON-TITLE I  */
/****************************************************************/

--DECLARE @DATAYEARS CHAR(8)
--SET @DATAYEARS='20102011'

DECLARE @PLAS_TIERII INT
SET @PLAS_TIERII = (SELECT ROUND(COUNT(*)*.05,0)
					FROM dbo.PLAS_TIERII
					WHERE DATAYEARS=@DATAYEARS)
/*
CHECK THE 5%
DECLARE @PLAS_TIERII INT
SET @PLAS_TIERII = (SELECT ROUND(COUNT(*)*.05,0)
					FROM dbo.PLAS_TIERII
					WHERE DATAYEARS='20112012')--@DATAYEARS)
PRINT @PLAS_TIERII
*/



SELECT TOP(@PLAS_TIERII)DATAYEARS,
AGENCYID,
DISTRICT_NAME,
SCHOOL_NAME,
GRADE_CODE,
TIER='TIER II',
REASON='Elig not served/Title I',
RANKED=FINAL_OPTION_AC_RANK 

INTO #PLAS_TIERII_NON_TITLEI
FROM NeSA.dbo.PLAS_TIERII
WHERE DATAYEARS=@DATAYEARS
AND (MINIMUM_NUMBER_READ='INCLUDE' OR MINIMUM_NUMBER_MATH='INCLUDE')
ORDER BY FINAL_OPTION_AC_RANK ASC


/****************************************************************/
/*  SELECT PLAS TIER III - ELGIBIGLE BUT NOT SERVED/NON-TITLE I  */
/****************************************************************/

SELECT DATAYEARS,
AGENCYID,
DISTRICT_NAME,
SCHOOL_NAME,
GRADE_CODE,
TIER='TIER III',
REASON='Elig not served/Title I',
RANKED=FINAL_OPTION_AC_RANK 
INTO #PLAS_TIERIII_NON_TITLEI
FROM NeSA.dbo.PLAS_TIERII
WHERE DATAYEARS=@DATAYEARS
AND (MINIMUM_NUMBER_READ='EXCLUDE' AND MINIMUM_NUMBER_MATH='EXCLUDE')
AND FINAL_OPTION_AC_RANK <= (SELECT MAX(A.FINAL_OPTION_AC_RANK)
								FROM NeSA.dbo.PLAS_TIERII AS A
								INNER JOIN #PLAS_TIERII_NON_TITLEI AS B ON
									A.AGENCYID = B.AGENCYID AND
									A.DATAYEARS = B.DATAYEARS)
AND AGENCYID NOT IN (SELECT AGENCYID FROM #PLAS_TIERII_NON_TITLEI)


/**************************************************************/
/********  GRADUATION RATE  ***********************************/
/**************************************************************/
/**************************************************************/
/*  SELECT PLAS TIER I - GRADUATION RATE                      */
/**************************************************************/

SELECT DATAYEARS=@DATAYEARS,
AGENCYID = A.COUNTY + '-' + A.DISTRICT + '-' + A.SCHOOL,
DISTRICT_NAME = B.NAME,
SCHOOL_NAME = A.NAME,
GRADE_CODE = 'NA',
TIER = 'TIER I',
REASON='Graduation Rate',
RANKED=grad_rank
INTO #PLAS_TIERI_GRAD_RATE
FROM dbo.PLAS_GRAD_RATE AS A
INNER JOIN STG_MART_NDE.dbo.AGENCIES AS B ON
	A.COUNTY + '-' + A.DISTRICT + '-' + '000' = B.AGENCYID AND
	A.DATAYEARS = B.DATAYEARS
WHERE A.DATAYEARS=@DATAYEARS
AND CAST(LEFT(AYP_GRAD_RATE,5) AS FLOAT)< 75.00
AND A.TITLE_ONE_STATUS = '1'
AND A.COUNTY + '-' + A.DISTRICT + '-' + A.SCHOOL NOT IN (SELECT AGENCYID FROM #PLAS_TIERI_TITLEI)



/**************************************************************/
/*  SELECT PLAS TIER II - GRADUATION RATE                      */
/**************************************************************/

SELECT DATAYEARS=@DATAYEARS,
AGENCYID = A.COUNTY + '-' + A.DISTRICT + '-' + A.SCHOOL,
DISTRICT_NAME = B.NAME,
SCHOOL_NAME = A.NAME,
GRADE_CODE = 'NA',
TIER = 'TIER II',
REASON='Graduation Rate',
RANKED=grad_rank
INTO #PLAS_TIERII_GRAD_RATE
FROM dbo.PLAS_GRAD_RATE AS A
INNER JOIN STG_MART_NDE.dbo.AGENCIES AS B ON
	A.COUNTY + '-' + A.DISTRICT + '-' + '000' = B.AGENCYID AND
	A.DATAYEARS = B.DATAYEARS
WHERE A.DATAYEARS=@DATAYEARS
AND CAST(LEFT(AYP_GRAD_RATE,5) AS FLOAT)< 75.00
AND A.TITLE_ONE_STATUS = '0'
AND A.COUNTY + '-' + A.DISTRICT + '-' + A.SCHOOL NOT IN (SELECT AGENCYID FROM #PLAS_TIERII_NON_TITLEI)
AND A.COUNTY + '-' + A.DISTRICT + '-' + A.SCHOOL NOT IN (SELECT AGENCYID FROM #PLAS_TIERI_GRAD_RATE)





/*  FOR ASPECT'S PLAS_IDENTIFIED_SCHOOLS TABLE   */
/*
CREATE TABLE NESA.dbo.PLAS_IDENTIFIED_SCHOOLS
(DATAYEARS CHAR(8),
 AGENCYID CHAR(11),
 DISTRICT_NAME VARCHAR(75),
 SCHOOL_NAME VARCHAR(75),
 GRADE_CODE CHAR(2),
 TIER VARCHAR(8))
*/


DELETE FROM #PLAS_TIERIII_TITLEI
WHERE AGENCYID IN (SELECT AGENCYID FROM #PLAS_TIERI_GRAD_RATE)



DELETE FROM NESA.dbo.PLAS_IDENTIFIED_SCHOOLS
WHERE DATAYEARS=@DATAYEARS

INSERT INTO NESA.dbo.PLAS_IDENTIFIED_SCHOOLS
(
      [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
)
SELECT 
      [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
FROM #PLAS_TIERI_TITLEI
UNION
SELECT [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
FROM #PLAS_TIERIII_TITLEI
UNION
SELECT [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
FROM #PLAS_TIERII_NON_TITLEI
UNION
SELECT [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
FROM #PLAS_TIERIII_NON_TITLEI
UNION
SELECT [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
FROM #PLAS_TIERI_GRAD_RATE
UNION
SELECT [DATAYEARS]
      ,[AGENCYID]
      ,[DISTRICT_NAME]
      ,[SCHOOL_NAME]
      ,[GRADE_CODE]
      ,[TIER]
      ,[REASON]
      ,[RANKED]
FROM #PLAS_TIERII_GRAD_RATE
ORDER BY AGENCYID

UPDATE NESA.dbo.PLAS_IDENTIFIED_SCHOOLS
SET [UPDATED_DATE] = @UPDATE_DATE,
    [PROCEDURE_NAME] = @PROCEDURE_NAME

/*  SELECT * FROM dbo.PLAS_IDENTIFIED_SCHOOLS   */

/*
drop table #PLAS_TIERI_GRAD_RATE
drop table #PLAS_TIERII_GRAD_RATE
drop table #PLAS_TIERII_NON_TITLEI
drop table #PLAS_TIERIII_NON_TITLEI
drop table #PLAS_TIERI_TITLEI
drop table #PLAS_TIERIII_TITLEI
*/