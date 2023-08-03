


--*************************************************************************************************************************************
--    Purpose:	Receive information from ESD UI in a XML string and update products mapping.

--    Date          User            Description
--************************************************************************************************************************************
--    2023-03-24	fjunio2x        Initial Release
--************************************************************************************************************************************

CREATE   PROCEDURE [dbo].[UspGuiEsdLoadXmlExcessItemsMappingFromExcel] (@xmlString TEXT, @LoadedByTool varchar(25), @EsdVersionId int)
AS
/****************************************************************************************
DESCRIPTION: This proc loads Wspw Historical Wafer starts from AIR. It runs on Recon DB server.
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS

	[dbo].[UspGuiEsdLoadXmlExcessItemsMappingFromExcel] 	 @xmlString = '<list><record><SnOPDemandProductNm>A-Gold 620T BGA</SnOPDemandProductNm><YyyyMm>202212</YyyyMm><AdjSellableSupply>5</AdjSellableSupply></record></list>' ,@LoadedByTool='ESU_POC',@EsdVersionId = 111

	DECLARE @xmlString VARCHAR(MAX) = ' <list><record><ItemId>2000-054-259</ItemId><ItemDescription>S8PHHAVD</ItemDescription><SDAFamily>HSW 2+2</SDAFamily><MMCodeName>HASWELL-H-2</MMCodeName><DLCP>HP</DLCP><SnOPDemandProductId /><SnOPDemandProductNm>Alder Lake H P 4P+8E BGA i5</SnOPDemandProductNm><RemoveInd>0</RemoveInd></record></list>'
DECLARE @LoadedByTool varchar(25) ='ESU_POC'
DECLARE @EsdVersionId INT = 111

-- TEST HARNESS */
--DECLARE @LoadedByTool varchar(25) ='ESU_POC'
--DECLARE @EsdVersionId INT = 111
--DECLARE @xmlString VARCHAR(MAX) = ' <list><record><ItemId>2000-054-259</ItemId><ItemDescription>S8PHHAVD</ItemDescription><SDAFamily>HSW 2+2</SDAFamily><MMCodeName>HASWELL-H-2</MMCodeName><DLCP>HP</DLCP><SnOPDemandProductId /><SnOPDemandProductNm>Alder Lake H P 4P+8E BGA i5</SnOPDemandProductNm><RemoveInd>0</RemoveInd></record></list>'

/*
<list>
<record>
<ItemId>2000-054-259</ItemId>
<ItemDescription>S8PHHAVD</ItemDescription>
<SDAFamily>HSW 2+2</SDAFamily>
<MMCodeName>HASWELL-H-2</MMCodeName>
<DLCP>HP</DLCP>
<SnOPDemandProductId />
<SnOPDemandProductNm>Alder Lake H P 4P+8E BGA i5</SnOPDemandProductNm>
<RemoveInd>0</RemoveInd>
</record>
</list>'
*/


 DECLARE @idoc				int
       , @now				datetime
	   , @user_id			varchar(50)
		
    SET @now = GETDATE()		
    --IF @user_id IS NULL
    SET @user_id = SYSTEM_USER

    EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString


	IF OBJECT_ID('tempdb..#TmpRefItemMapping') IS NOT NULL 
	    drop table #TmpRefItemMapping;

	CREATE TABLE #TmpRefItemMapping(
		ItemId VARCHAR(50),
		SnOPDemandProductNm VARCHAR(100),
		SDAFamily VARCHAR(50),
		RemoveInd Bit
	) 

	INSERT INTO #TmpRefItemMapping
		 (
		   ItemId
		 , SnOPDemandProductNm
		 , SDAFamily
		 , RemoveInd
	     )
	SELECT ItemId 
	     , SnOPDemandProductNm   
		 , SDAFamily
		 , RemoveInd
	FROM 	OPENXML (@idoc, '/list/record', 2)
	WITH (
           ItemId VARCHAR(100)
         , SnOPDemandProductNm VARCHAR(100)
		 , SDAFamily VARCHAR(50)
		 , RemoveInd Bit
		 ) T1

    EXEC sp_xml_removedocument @idoc

	SELECT * FROM #TmpRefItemMapping

	--UPDATE Rows that have already been altered but the Quantity has changed
	UPDATE [dbo].[StgDiePrepItemsMap]
    SET    SnOPDemandProductId = Prod.SnOPDemandProductId
	     , SnOPDemandProductNm = Prod.SnOPDemandProductNm
		 , SdaFamily           = Tmp.SDAFamily
		 , RemoveInd           = IsNull(Tmp.RemoveInd,0)
	FROM   [dbo].[StgDiePrepItemsMap] DPIM 	                                                                                 JOIN 
	       #TmpRefItemMapping Tmp                  ON Tmp.ItemId               = IsNull(DPIM.ItemId,DPIM.ItemDescription)  LEFT JOIN 
		   [dbo].[SnOPDemandProductHierarchy] Prod ON Prod.SnOPDemandProductNm = Tmp.SnOPDemandProductNm 

    INSERT INTO [dbo].[StgDiePrepItemsMap]
    SELECT 
   		   Tmp.ItemId
		 , NULL
		 , tmp.SDAFamily
		 , NULL
		 , NULL
		 , SnOPDemandProductId
		 , Prod.SnOPDemandProductNm
		 , IsNull(tmp.RemoveInd,0)
		 , getdate()
		 , 'Test'
    FROM   #TmpRefItemMapping                 Tmp   LEFT JOIN 
		   [dbo].[SnOPDemandProductHierarchy] Prod ON Prod.SnOPDemandProductNm = Tmp.SnOPDemandProductNm 
	WHERE  Not Exists (Select 1 From [dbo].[StgDiePrepItemsMap] Die Where Die.ItemId = Tmp.ItemId)

END

