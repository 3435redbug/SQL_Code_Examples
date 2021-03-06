USE [NDE_GMS_MART]
GO
/****** Object:  StoredProcedure [dbo].[zspMRMAggregatedNotComplete]    Script Date: 12/18/2015 12:36:01 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[zspMRMAggregatedNotComplete]  @sintyear int


AS

SET NOCOUNT ON;


--DECLARE @SINTYEAR INT
--SET @SINTYEAR=2002

select	A.bintAplyInstId,a.bintOrgInstId,a.bintPrgGrpMembInstId,a.sintYr,
		b.bintAplyCycleInstId,b.vchrName as 'RR#',b.chrCloseFlag,b.dtmLastModfDate,
		c.curTotPropsExpnd,
		c.sintseqnum,
		P.vchrtypecode,p.vchrname as 'Federal Program',
		PG.bintPrgGrpInstId,pg.vchrName as 'Federal Program Group',
		'        ' as 'Day_Count'
into #rr_list
		from  ndeasa.dbo.tbegmsasaaply a 
		INNER JOIN ndeasa.dbo.tbegmsasaaplycycle b 
               ON a.bintaplyinstid = b.fkbintaplyinstid 
		INNER JOIN ndeasa.dbo.tbegmsasaaplybdgtline c 
               ON b.bintaplycycleinstid = c.fkbintaplycycleinstid 
		INNER JOIN ndeasa.dbo.tbegmsasaaplybdgtdtl d 
               ON c.bintaplybdgtlineinstid = d.fkbintaplybdgtlineinstid
		inner join [nderef].[dbo].[tbEgmsrefPrgGroupMember] as PGM on
				PGM.bintPrgGrpMembInstId = A.bintPrgGrpMembInstId
		inner join [nderef].[dbo].[tbEgmsrefPrgGroup] as PG on
				PG.bintPrgGrpInstId=PGM.bintPrgGrpInstId
		INNER JOIN [nderef].[dbo].[tbEgmsrefProgram] as P ON
				P.bintPrgInstId=PGM.bintPrgInstId
where	B.vchrname like 'REIMBRQST%' and 
		c.sintseqnum <> 99 and
		chrcloseflag  in ('Y') and
		chrLogicalDelInd <> 'Y' and
		a.sintYr > @sintyear




UPDATE #rr_list
SET DAY_COUNT = DATEDIFF(DAY,(CONVERT(VARCHAR(10),dtmLastModfDate,110)),(CONVERT(VARCHAR(10),GETDATE(),110)))
FROM #rr_list



select	ac.bintAplyCycleInstId,
		sd.vchrTypeCd,
		sdv.dtmLastModfDate,sdv.vchrtextval
into #fs_status
from [ndeasa].[dbo].[tbEgmsasaAplyCycle] as ac 
inner join [ndeasa].[dbo].[tbEgmsasaAplySuppData] sd on
	sd.fkbintAplyCycleInstId=ac.bintAplyCycleInstId
inner join [ndeasa].[dbo].[tbEgmsasaAplySuppDataVal] as sdv on
	sdv.fkbintAplySuppDataInstId=sd.bintAplySuppDataInstId
where	sd.vchrTypeCd like 'fs%' and
		sdv.vchrTypeCd='value' 
order by ac.bintAplyCycleInstId




select r.*, fs.vchrtextval AS FS_STATUS
INTO #RR_LIST_UPDT1
from #rr_list as r
left join #fs_status as fs on
	r.bintAplyCycleInstId=fs.bintaplycycleinstid




SELECT AC.bintAplyCycleInstId,MD.MAX_DATE,AA.chrAprvCd,AA.vchrAprvGrpName
INTO #MAX_APRV_DATE
FROM [ndeasa].[dbo].[tbEgmsasaAplyCycle] AS AC
INNER JOIN [ndeasa].[dbo].[tbEgmsasaAplyAprv] AS AA ON
	AC.bintAplyCycleInstId=AA.fkbintAplyCycleInstId
INNER JOIN (SELECT MAX(AA.dtmAprvDate) AS MAX_DATE,AC.bintAplyCycleInstId
			FROM [ndeasa].[dbo].[tbEgmsasaAplyCycle] AS AC
			INNER JOIN [ndeasa].[dbo].[tbEgmsasaAplyAprv] AS AA ON
				AC.bintAplyCycleInstId=AA.fkbintAplyCycleInstId
			GROUP BY AC.bintAplyCycleInstId) AS MD ON
	AC.bintAplyCycleInstId=MD.bintAplyCycleInstId AND
	AA.dtmAprvDate=MD.MAX_DATE



select r.*, mad.chrAprvCd as APRV_CD
INTO #RR_LIST_UPDT2
from #RR_LIST_UPDT1 as r
left join #MAX_APRV_DATE as mad on
	r.bintAplyCycleInstId=mad.bintaplycycleinstid



DELETE FROM #RR_LIST_UPDT2
WHERE FS_STATUS IN ('COMPLETE AND ACCEPTABLE')

DELETE FROM #RR_LIST_UPDT2
WHERE APRV_CD IN ('DISAPPROVE')


CREATE TABLE #TOT_NCA
(
SINTYR			CHAR(4),
PROGRAM			CHAR(75),
TOT_NUM_NCA		INT,
TOT_DOLLARS		INT,
TOT_NUM_NCA30	INT,
TOT_DOLLARS_NCA30	INT,
TOT_NUM_NCA60	INT,
TOT_DOLLARS_NCA60	INT,
TOT_NUM_NCA90	INT,
TOT_DOLLARS_NCA90	INT,
TOT_NUM_NCA90P	INT,
TOT_DOLLARS_NCA90P	INT
)


INSERT INTO #TOT_NCA (SINTYR,PROGRAM)
SELECT DISTINCT SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
FROM #RR_LIST_UPDT2


INSERT INTO #TOT_NCA (SINTYR,PROGRAM)
VALUES (2099,'TOTAL')
INSERT INTO #TOT_NCA (SINTYR,PROGRAM)
VALUES (2100,'PERCENT OF TOTAL')



/****  UPDATE TOTAL NUMBER OF REQUESTS NOT MARKED COMPLETE & ACCEPTABLE    ****/

UPDATE #TOT_NCA 
SET TOT_NUM_NCA =	(	SELECT CASE WHEN COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId) <> 0 THEN COUNT(distinct BINTPRGGRPMEMBINSTID + bintAplyCycleInstId)
									ELSE 0 END
						FROM #RR_LIST_UPDT2 AS B
						WHERE	#TOT_NCA.SINTYR=B.SINTYR AND
								#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
						GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' )


UPDATE #TOT_NCA 
SET TOT_NUM_NCA30 = CASE WHEN (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT <= 30 AND
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT <= 30 AND
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END

UPDATE #TOT_NCA 
SET TOT_NUM_NCA60 =CASE WHEN (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT <= 60 AND B.DAY_COUNT > 30 AND 
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT <= 60 AND B.DAY_COUNT > 30 AND 
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END

UPDATE #TOT_NCA 
SET TOT_NUM_NCA90 = CASE WHEN (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT <= 90 AND B.DAY_COUNT > 60 AND 
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT <= 90 AND B.DAY_COUNT > 60 AND 
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END

UPDATE #TOT_NCA 
SET TOT_NUM_NCA90P = CASE WHEN (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT > 90 AND
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT COUNT(distinct bintPrgGrpMembInstId + bintAplyCycleInstId)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT > 90 AND
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END



/****  UPDATE TOTAL DOLLARS OF REQUESTS NOT MARKED COMPLETE & ACCEPTABLE    ****/

UPDATE #TOT_NCA 
SET TOT_DOLLARS =	(	SELECT CASE WHEN SUM(curTotPropsExpnd) <> 0 THEN SUM(curTotPropsExpnd)
									ELSE 0 END
						FROM #RR_LIST_UPDT2 AS B
						WHERE	#TOT_NCA.SINTYR=B.SINTYR AND
								#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
						GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' )


UPDATE #TOT_NCA 
SET TOT_DOLLARS_NCA30 = CASE WHEN (	SELECT  SUM(B.curTotPropsExpnd)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT <= 30 AND
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT SUM(B.CURTOTPROPSEXPND)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT <= 30 AND
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END

UPDATE #TOT_NCA 
SET TOT_DOLLARS_NCA60 = CASE WHEN (	SELECT  SUM(B.curTotPropsExpnd)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT <= 60 AND B.Day_Count > 30 AND
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT SUM(B.CURTOTPROPSEXPND)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT <= 60 AND B.Day_Count > 30 AND
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END

UPDATE #TOT_NCA 
SET TOT_DOLLARS_NCA90 = CASE WHEN (	SELECT  SUM(B.curTotPropsExpnd)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.DAY_COUNT <= 90 AND B.Day_Count > 60 AND
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT SUM(B.CURTOTPROPSEXPND)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.DAY_COUNT <= 90 AND B.Day_Count > 60 AND
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END

UPDATE #TOT_NCA 
SET TOT_DOLLARS_NCA90P = CASE WHEN (	SELECT  SUM(B.curTotPropsExpnd)
								FROM #RR_LIST_UPDT2 AS B
								WHERE	B.Day_Count > 90 AND
										#TOT_NCA.SINTYR=B.SINTYR AND
										#TOT_NCA.PROGRAM=[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
								GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')') IS NULL THEN 0
					ELSE (	SELECT SUM(B.CURTOTPROPSEXPND)
							FROM #RR_LIST_UPDT2 AS B
							WHERE	B.Day_Count > 90 AND
									#TOT_NCA.SINTYR=B.SINTYR AND
									#TOT_NCA.PROGRAM=B.[Federal Program Group] + ' ' + '(' + [Federal Program] + ')' 
							GROUP BY B.SINTYR,[Federal Program Group] + ' ' + '(' + [Federal Program] + ')')
					END



/*  UPDATE TOTALS FOR SHANE'S FINAL REPORT  */

/*  TOTAL DAYS  */
UPDATE #TOT_NCA
SET TOT_NUM_NCA = (	SELECT SUM(TOT_NUM_NCA)
					FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA30 = (	SELECT SUM(TOT_NUM_NCA30)
						FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA60 = (	SELECT SUM(TOT_NUM_NCA60)
					FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA90 = (	SELECT SUM(TOT_NUM_NCA90)
					FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA90P = (	SELECT SUM(TOT_NUM_NCA90P)
					FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


/*  TOTAL DOLLARS  */
UPDATE #TOT_NCA
SET TOT_DOLLARS = (	SELECT SUM(TOT_DOLLARS)
						FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA30 = (	SELECT SUM(TOT_DOLLARS_NCA30)
							FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA60 = (	SELECT SUM(TOT_DOLLARS_NCA60)
							FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA90 = (	SELECT SUM(TOT_DOLLARS_NCA90)
						FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA90P = (	SELECT SUM(TOT_DOLLARS_NCA90P)
					FROM #TOT_NCA )
WHERE PROGRAM='TOTAL'


/*  PERCENT OF TOTAL CALCULATED  */

UPDATE #TOT_NCA
SET TOT_NUM_NCA30 = (select round((convert(decimal(10,4),TOT_NUM_NCA30)/convert(decimal(10,4),TOT_NUM_NCA)*100),0)
					 from #TOT_NCA
					 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA60 = (select round((convert(decimal(10,4),TOT_NUM_NCA60)/convert(decimal(10,4),TOT_NUM_NCA)*100),0)
					 from #TOT_NCA
					 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA90 = (select round((convert(decimal(10,4),TOT_NUM_NCA90)/convert(decimal(10,4),TOT_NUM_NCA)*100),0)
					 from #TOT_NCA
					 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'


UPDATE #TOT_NCA
SET TOT_NUM_NCA90p = (select round((convert(decimal(10,4),TOT_NUM_NCA90P)/convert(decimal(10,4),TOT_NUM_NCA)*100),0)
					  from #TOT_NCA
					  where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'



UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA30 = (SELECT round((convert(decimal(10,2),TOT_DOLLARS_NCA30)/convert(decimal(10,2),TOT_DOLLARS)*100),0)
						 from #TOT_NCA
						 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA60 = (select round((convert(decimal(10,2),TOT_DOLLARS_NCA60)/convert(decimal(10,2),TOT_DOLLARS)*100),0)
						 from #TOT_NCA
						 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA90 = (select round((convert(decimal(10,2),TOT_DOLLARS_NCA90)/convert(decimal(10,2),TOT_DOLLARS)*100),0)
						 from #TOT_NCA
						 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'


UPDATE #TOT_NCA
SET TOT_DOLLARS_NCA90p = (select round((convert(decimal(10,2),TOT_DOLLARS_NCA90P)/convert(decimal(10,2),TOT_DOLLARS)*100),0)
						 from #TOT_NCA
						 where program='total')
WHERE PROGRAM='PERCENT OF TOTAL'




SELECT
SINTYR				as 'RRYear',
PROGRAM				as 'Program',
TOT_NUM_NCA			as 'Total # Not Marked Complete & Acceptable',		
TOT_DOLLARS			as 'Total $ Not Marked Complete & Acceptable',
TOT_NUM_NCA30		as 'Total # Not Marked Complete & Acceptable 0-30 Days Old',
TOT_DOLLARS_NCA30	as 'Total $ Not Marked Complete & Acceptable 0-30 Days Old',
TOT_NUM_NCA60		as 'Total # Not Marked Complete & Acceptable 31-60 Days Old',
TOT_DOLLARS_NCA60	as 'Total $ Not Marked Complete & Acceptable 31-60 Days Old',
TOT_NUM_NCA90		as 'Total # Not Marked Complete & Acceptable 61-90 Days Old',
TOT_DOLLARS_NCA90	as 'Total $ Not Marked Complete & Acceptable 61-90 Days Old',
TOT_NUM_NCA90P		as 'Total # Not Marked Complete & Acceptable More Than 90 Days Old',
TOT_DOLLARS_NCA90P	as 'Total $ Not Marked Complete & Acceptable More Than 90 Days Old'
FROM #TOT_NCA

