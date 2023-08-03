

--***************************************************************************************************************************************************
--    Purpose:	Send information of FabMps, OneMps and Compass to ESD UI.

--    Date          User            Description
--*********************************************************************************
--    2023-03-23	fjunio2x        Initial Release
--*********************************************************************************


CREATE   PROCEDURE [dbo].[UspGuiEsdFetchExcessItemsMapping]
@EsdVersionId int
AS 
--DECLARE @EsdVersionId int = 182

Select ItemId
     , ItemDescription
     , SDAFamily
	 , MMCodeName
     , DLCPProc
     , SnOPDemandProductNm
     , RemoveInd
Into #TmpDiePrepItemsMap
From (
		-- FABMPS
		Select Distinct Die.ItemId COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemId
			 , Die.ItemDescription COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , Fab.SdaFamilies     COLLATE SQL_Latin1_General_CP1_CI_AS AS SDAFamily
			 , Die.MMCodeName
			 , Die.DLCPProc
			 , Prod.SnOPDemandProductNm
			 , RemoveInd
		From   [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_FabMps] Fab                                                           LEFT JOIN
			   [dbo].[StgDiePrepItemsMap]         Die  On Die.ItemDescription        = Fab.Item COLLATE SQL_Latin1_General_CP1_CI_AS  LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod On Prod.[SnOPDemandProductId] = Die.[SnOPDemandProductId]
		Where  Die.ItemId Is Not Null
		  And  Fab.ItemClass = 'DIE PREP'
		  And  Not Exists ( Select 1 From [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_OneMps] OneMps Where OneMps.Item = Fab.Item)

		UNION

		-- ONEMPS
		Select Distinct Die.ItemId COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemId
			 , Die.ItemDescription COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , OneMps.SdaFamilies  COLLATE SQL_Latin1_General_CP1_CI_AS AS SDAFamily
			 , Die.MMCodeName
			 , Die.DLCPProc
			 , Prod.[SnOPDemandProductNm]
			 , RemoveInd
		From   [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_OneMps] OneMps                                                           LEFT JOIN
			   [dbo].[StgDiePrepItemsMap]         Die  On Die.ItemDescription        = OneMps.Item COLLATE SQL_Latin1_General_CP1_CI_AS  LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod On Prod.[SnOPDemandProductId] = Die.[SnOPDemandProductId]
		Where  Die.ItemId Is Not Null
		  And  OneMps.ItemClass = 'DIEPREP'

		UNION 

		-- Compass
		Select DISTINCT Compass.ItemId COLLATE SQL_Latin1_General_CP1_CI_AS
			 , Die.ItemDescription COLLATE SQL_Latin1_General_CP1_CI_AS
			 , 'Compass' SdaFamily
			 , Die.MMCodeName
			 , Die.DLCPProc
			 , Prod.SnOPDemandProductNm
			 , RemoveInd
		FROM [dbo].[CompassDieEsuExcess] Compass LEFT JOIN
			 [dbo].[StgDiePrepItemsMap]  Die         On Die.ItemId = Compass.ItemId COLLATE SQL_Latin1_General_CP1_CI_AS  LEFT JOIN
			 [dbo].[SnOPDemandProductHierarchy] Prod On Prod.[SnOPDemandProductId] = Die.[SnOPDemandProductId]
		WHERE Compass.EsdVersionId = @EsdVersionId
) As V

Delete #TmpDiePrepItemsMap
Where  ItemId In 
(
Select ItemId
From   #TmpDiePrepItemsMap  
Group by ItemId
Having Count(*) > 1
)
And SdaFamily = 'Compass'

Select * 
From #TmpDiePrepItemsMap 