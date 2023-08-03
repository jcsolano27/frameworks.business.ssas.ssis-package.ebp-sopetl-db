

CREATE PROC [dbo].[UspGuiFetchEsdVersionDatasetDetails](@EsdVersionId integer)
AS

/*
	[dbo].[UspGuiFetchEsdVersionDatasetDetails] 41
*/
--DECLARE @EsdVersionId integer = 150;

WITH CTE_EsdLoadGroups as (
	SELECT DISTINCT 
		TableLoadGroupId
		,TableLoadGroupName
	FROM [dbo].[EtlTableLoadGroups]
	WHERE GroupType = 'ESD'
	AND TableLoadGroupId NOT in (1, 2,12)
)

,CTE_EsdVersions AS (
	SELECT DISTINCT
		EsdVersionId
		,EsdVersionName
	FROM dbo.EsdVersions
)
,CTE_CROSS AS (
	SELECT * FROM CTE_EsdLoadGroups A
	CROSS APPLY CTE_EsdVersions B
)
--SELECT * FROM CTE_CROSS
--ORDER BY EsdVersionId,TableLoadGroupId


,CTE_RequestedVersions AS
(
	SELECT DISTINCT
		CR.EsdVersionId
		,CR.EsdVersionName
		,CR.TableLoadGroupId
		,CR.TableLoadGroupName
		,LR.DataLoadRequestId 
		,RANK() OVER(PARTITION BY CR.EsdVersionId,CR.TableLoadGroupName ORDER BY DataLoadRequestId DESC,s.StatusName DESC ,LR.CreatedOn DESC) AS Ranking
		--,MIN(LR.CreatedOn) As BatchRequestedOn
		,LR.CreatedOn As BatchRequestedOn
		,LR.CreatedBy
		,s.StatusName
		,1 AS TableLoadGroupInd
		,CASE WHEN CR.TableLoadGroupName IN ('Bonusback') THEN 0 ELSE 0 END AS CheckedByDefault
	FROM CTE_CROSS CR
	LEFT JOIN [dbo].[GuiUIDataLoadRequest] LR
		ON CR.EsdVersionId = LR.EsdVersionId
		AND CR.TableLoadGroupId=LR.TableLoadGroupId
	LEFT  JOIN dbo.EsdVersions ev
		ON ev.EsdVersionId = lr.EsdVersionId
	LEFT JOIN[dbo].[EtlBatchRuns]  br
		ON br.BatchRunId = lr.BatchRunId
	LEFT  JOIN [dbo].[EtlBatchRunStatus] s
		ON s.BatchRunStatusId = br.BatchRunStatusId)


SELECT  TableLoadGroupId,
TableLoadGroupName 
--,DataLoadRequestId
,BatchRequestedOn AS LastLoadDate
,CreatedBy AS LastLoadedBy
,CASE 
	WHEN StatusName is null THEN 'Not Loaded'
	Else StatusName
	End As LoadStatus
,TableLoadGroupInd
,CheckedByDefault
FROM CTE_RequestedVersions
WHERE EsdVersionId = @EsdVersionId
	AND Ranking=1


	--Removed 3_16 by Jeremy, Breaking out Datasets into separate UI Component
--UNION ALL

--SELECT DA.TableLoadGroupId, DA.DatasetName,DR.LastLoadDate,DR.LastLoadedBy
--	,CASE WHEN DR.LastLoadDate IS NOT NULL THEN 'Completed' ELSE 'Not Loaded' END AS [Status]
--	,TableLoadGroupInd
--	,CheckedByDefault
--FROM CTE_AllDatasets DA
--LEFT OUTER JOIN CTE_OtherDatasets DR
--	ON DA.DatasetName = DR.DatasetName



