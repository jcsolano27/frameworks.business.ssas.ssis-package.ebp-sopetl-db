






CREATE PROCEDURE [dbo].[UspGuiEsdFetchSourceVersionBypass]
AS 
--DECLARE @EsdVersionId int = 33

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
	T2.SourceVersionId
	--COALESCE(CAST(T2.SourceVersionId AS VARCHAR(40)),'MISSING') AS SourceVersionId
FROM #tmpBypassVersions T1
LEFT OUTER JOIN
dbo.EsdVersionsBypass T2
	ON T1.SourceApplicationName = T2.SourceApplication
	AND T1.Division = T2.Division










