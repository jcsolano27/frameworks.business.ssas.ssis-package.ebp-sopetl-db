






CREATE PROCEDURE [dbo].[UspGuiEsdFetchSourceVersionUpdate] @EsdVersionId int
AS 
--DECLARE @EsdVersionId int = 114

IF OBJECT_ID('tempdb..#tmpBypassVersions') IS NOT NULL DROP TABLE #tmpBypassVersions
CREATE TABLE #tmpBypassVersions(SourceApplicationName VARCHAR(100),Division VARCHAR(100), SourceVersionId INT)

INSERT INTO #tmpBypassVersions (SourceApplicationName,Division)
SELECT 'FabMps',''
UNION
SELECT 'Compass',''
UNION
--SELECT 'FabMps', 'IOT'
--UNION
SELECT 'IsMps',''
UNION 
SELECT 'OneMps',''

SELECT 
	T1.SourceApplicationName,
	T1.Division,
--	T2.SourceVersionId,
	COALESCE(T2.SourceVersionId,-1) AS SourceVersionId

FROM #tmpBypassVersions T1
LEFT OUTER JOIN
	(select b.*, a.[SourceApplicationName] from [dbo].[EtlSourceApplications] a join dbo.EsdSourceVersions b on a.[SourceApplicationId] = b.[SourceApplicationId]) T2
	ON T1.SourceApplicationName = T2.[SourceApplicationName]
	AND T2.EsdVersionId = @EsdVersionId




SELECT 'SourceApplicationName' as KeyCol





