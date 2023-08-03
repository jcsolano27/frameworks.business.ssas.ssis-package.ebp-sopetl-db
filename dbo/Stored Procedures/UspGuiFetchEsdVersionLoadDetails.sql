
CREATE PROC dbo.[UspGuiFetchEsdVersionLoadDetails](@EsdVersionId integer)  
AS  
  
--DECLARE @EsdVersionId integer = 111;  
  
WITH CTE_EsdLoadGroups as (  
 SELECT DISTINCT   
  TableLoadGroupId  
  ,TableLoadGroupName  
 FROM  [dbo].[EtlTableLoadGroups]
 WHERE GroupType = 'ESD'  
 AND TableLoadGroupId <> 2  
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
 FROM CTE_CROSS CR  
 LEFT JOIN dbo.GuiUIDataLoadRequest LR  
  ON CR.EsdVersionId = LR.EsdVersionId  
  AND CR.TableLoadGroupId=LR.TableLoadGroupId  
 LEFT  JOIN dbo.EsdVersions  ev  
  ON ev.EsdVersionId = lr.EsdVersionId  
 LEFT JOIN [dbo].[EtlBatchRuns] br  
  ON br.BatchRunId = lr.BatchRunId  
 LEFT  JOIN [dbo].[EtlBatchRunStatus] s  
  ON s.BatchRunStatusId = br.BatchRunStatusId  
)  

  
SELECT  TableLoadGroupId,  
TableLoadGroupName  
,DataLoadRequestId  
,BatchRequestedOn  
,CreatedBy  
,CASE   
 WHEN StatusName is null THEN 'Completed'  
 Else StatusName  
 End As LoadStatus  
FROM CTE_RequestedVersions  
WHERE EsdVersionId = @EsdVersionId  
 AND Ranking=1  
ORDER BY TableLoadGroupName ASC, EsdVersionId DESC ,  DataLoadRequestId ASC  


