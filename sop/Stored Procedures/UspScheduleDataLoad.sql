/*********************************************************************************        
      
----    Purpose: Schedule data loads for the current day        
        
----    Called by:  Autosys
      
Date        User            Description        
**********************************************************************************        
2023-07-20	caiosanx		Initial Release
**********************************************************************************/

CREATE PROC sop.UspScheduleDataLoad
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

DECLARE TableLoadGroupCursor CURSOR FORWARD_ONLY FOR
SELECT X.TableLoadGroupId
FROM
(
    SELECT DISTINCT
           TableLoadGroupId,
           CASE
               WHEN TableLoadGroupName = 'Dimension' 
			   THEN 0

               WHEN TableLoadGroupName = 'Revenue'
			   THEN 5

               WHEN TableLoadGroupName = 'Svd Dimension' 
			   THEN 0

               WHEN TableLoadGroupName = 'Sales' 
			   THEN 0
               
			   WHEN TableLoadGroupName = 'EsdVersion' 
			   THEN 0
               
			   WHEN TableLoadGroupName = 'Billings' 
			   THEN 0

               WHEN TableLoadGroupName = 'ConsensusDemand' 
			   THEN 0

               WHEN TableLoadGroupName = 'Capacity' 
			   THEN 0

               WHEN TableLoadGroupName = 'ProdCoCustomerOrderVolumeOpenConfirmed' 
			   THEN 0

               WHEN TableLoadGroupName = 'ProdCoCustomerOrderVolumeOpenUnconfirmed' 
			   THEN 0

               WHEN TableLoadGroupName = 'ProdCoRequestBeFull' 
			   THEN 0

               WHEN TableLoadGroupName = 'FullTargetUnconstrainedSolve' 
			   THEN 5
           END ScheduleWeekDay
    FROM sop.TableLoadGroup
    WHERE GroupType = 'Scheduled'
) X
WHERE X.ScheduleWeekDay = DATEPART(WEEKDAY, GETDATE());

OPEN TableLoadGroupCursor;

DECLARE @TableLoadGroupId VARCHAR(2);

FETCH NEXT FROM TableLoadGroupCursor
INTO @TableLoadGroupId;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = @TableLoadGroupId;
   
    FETCH NEXT FROM TableLoadGroupCursor
    INTO @TableLoadGroupId;
END;

CLOSE TableLoadGroupCursor;

DEALLOCATE TableLoadGroupCursor;
