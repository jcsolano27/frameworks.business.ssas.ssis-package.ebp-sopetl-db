
CREATE   VIEW [dbo].[v_SnOPCompassMRPFabRoutingHist]
AS
----/*********************************************************************************
----    Purpose:		This view is meant to display the historical records from SnOPCompassMRPFabRoutingHist and the latest and overwritten PublishLogIds from the SnOPCompassMRPFabRouting table.
----    Tables Used:	[dbo].[SnOPCompassMRPFabRouting]/[dbo].[SnOPCompassMRPFabRoutingHist]

----    Called by:      Denodo

----    Result sets:    None

----    Parameters: None

----    Return Codes: None

----    Exceptions: None expected

----    Date        User            Description
----***************************************************************************-
----    2023-04-10  rmiralhx        Initial Release

----*********************************************************************************/
SELECT [RowId]
      ,[PublishLogId]
      ,[SourceItem]
      ,[ItemName]
      ,[LocationName]
      ,[ParameterTypeName]
      ,[Quantity]
      ,[OriginalQuantity]
      ,[BucketType]
      ,[FiscalYearWorkWeekNbr]
      ,[FabProcess]
      ,[DotProcess]
      ,[LrpDieNm]
      ,[TechNode]
      ,[SourceApplicationName]
      ,[IsOverride]
      ,[CreatedOn]
      ,[CreatedBy]
      ,[UpdatedOn]
      ,[UpdatedBy]
      ,[UpdateComment]
  FROM [dbo].[SnOPCompassMRPFabRouting]
  
  UNION ALL 
  
  SELECT [RowId]
      ,[PublishLogId]
      ,[SourceItem]
      ,[ItemName]
      ,[LocationName]
      ,[ParameterTypeName]
      ,[Quantity]
      ,[OriginalQuantity]
      ,[BucketType]
      ,[FiscalYearWorkWeekNbr]
      ,[FabProcess]
      ,[DotProcess]
      ,[LrpDieNm]
      ,[TechNode]
      ,[SourceApplicationName]
      ,[IsOverride]
      ,[CreatedOn]
      ,[CreatedBy]
	  ,NULL AS [UpdatedOn]
      ,NULL AS [UpdatedBy]
      ,NULL AS [UpdateComment]
  FROM [dbo].[SnOPCompassMRPFabRoutingHist]
