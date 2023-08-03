







CREATE PROCEDURE [dbo].[UspGuiEsdFetchDemandProfitCenter]
AS 
--DECLARE @EsdVersionId int = 33


SELECT 
	'PC For Demand' as PCForDemand,
	ProfitCenterName,
	ProfitCenterID

FROM [dbo].[GuiUIDemandProfitCenter]



