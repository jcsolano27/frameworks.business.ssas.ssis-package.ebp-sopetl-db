

CREATE PROCEDURE [dbo].[UspGuiEsdFetchTableLoadGroups]
AS 

SELECT [TableLoadGroupName]
	  ,[TableLoadGroupId]
      ,[Description]
	  ,CASE WHEN TableLoadGroupName IN ('MPS') THEN 1 ELSE 0 END AS CheckedByDefault
 FROM [dbo].[EtlTableLoadGroups]
WHERE GroupType = 'ESD'
AND TableLoadGroupId NOT IN (1,2,12) -- Temp solution to only show the groups that will be loaded.
  --WHERE lower([Description]) Not like '%schedule%';


