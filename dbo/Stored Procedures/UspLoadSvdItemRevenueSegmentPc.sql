CREATE PROC [dbo].[UspLoadSvdItemRevenueSegmentPc]
WITH EXECUTE AS OWNER
AS

----/*********************************************************************************  

----    Purpose:		LOAD NEW DATA INTO [SvdItemRevenueSegmentPc] AND UPDATE MODIFIED DATA IN IT
----	Source:			[StgItemRevenueSegmentPc]
----	Destination:	[SvdItemRevenueSegmentPc]

----    Called by:		SSIS

----    Date        User            Description  
----***************************************************************************-  

---- 2022-10-17		caiosanx		INITIAL RELEASE
---- 2023-03-22		atairumx		Adjustments in logic, because according to MERGE condition, there are some cases with duplicate key.
---- 2023-04-14		caiosanx		Updating business logic so revenue segments would be activated or inactivated according to the data source values.

----*********************************************************************************/  

BEGIN

SET NOCOUNT ON

DECLARE @CurrentDateTime DATETIME = GETDATE(); 

WITH CteItemRevenueSegmentPc
AS (	
	SELECT RevenueSegmentNm,
           ProfitCenterCd,
           EffectiveFromQuarterNm,
           EffectiveToQuarterNm,
           CreatedOn,
           CreatedBy,
           1 IsActive
    FROM [dbo].[StgItemRevenueSegmentPC]
    WHERE EffectiveToQuarterNm >= CONCAT(YEAR(@CurrentDateTime), 'Q', DATEPART(QUARTER, @CurrentDateTime)))

MERGE [dbo].[SvdItemRevenueSegmentPc] AS D --Destination Table
USING CteItemRevenueSegmentPc AS S --Source Table
ON (
       D.[RevenueSegmentNm] = S.[RevenueSegmentNm]
       AND D.[ProfitCenterCd] = S.[ProfitCenterCd]
   )
WHEN MATCHED AND D.LastModifiedDt <> @CurrentDateTime THEN
    UPDATE SET D.LastModifiedDt = @CurrentDateTime,
               D.CreatedBy = ORIGINAL_LOGIN(),
               D.IsActive = 1
WHEN NOT MATCHED THEN
    INSERT VALUES
           (S.RevenueSegmentNm, S.ProfitCenterCd, @CurrentDateTime, @CurrentDateTime, ORIGINAL_LOGIN(), S.IsActive)
WHEN NOT MATCHED BY SOURCE 
THEN 
	UPDATE SET D.IsActive = 0;

END