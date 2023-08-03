






CREATE PROC [dbo].[UspGuiEsdLoadXmlAdjAtmConstrainedSupplyFromExcel] (@xmlString TEXT,@LoadedByTool varchar(25),@EsdVersionId int)
AS
/****************************************************************************************
DESCRIPTION: This proc loads Wspw Historical Wafer starts from AIR. It runs on Recon DB server.
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [esd].[UspLoadXMLAdjAtmConstrainedSupplyFromExcel]	 @xmlString = '<list><record><SnOPDemandProductNm>A-Gold 620T BGA</SnOPDemandProductNm><YyyyMm>202302</YyyyMm><AdjAtmConstrainedSupply>6</AdjAtmConstrainedSupply></record><record><SnOPDemandProductNm>Adairsville BGA</SnOPDemandProductNm><YyyyMm>202302</YyyyMm><AdjAtmConstrainedSupply>9</AdjAtmConstrainedSupply></record></list>' @LoadedByTool='ESU_POC'
-- TEST HARNESS */

--declare @xmlString varchar(max) = '<list><record><SnOPDemandProductNm>A-Gold 620T BGA</SnOPDemandProductNm><YyyyMm>202302</YyyyMm><AdjAtmConstrainedSupply>6</AdjAtmConstrainedSupply></record><record><SnOPDemandProductNm>Adairsville BGA</SnOPDemandProductNm><YyyyMm>202302</YyyyMm><AdjAtmConstrainedSupply>9</AdjAtmConstrainedSupply></record></list>' 
--declare @LoadedByTool varchar(max) ='ESU_POC'
--declare @EsdVersionId int = 111

 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString


		IF OBJECT_ID('tempdb..#TmpRefAdjAtmConstrainedSupply') IS NOT NULL drop table #TmpRefAdjAtmConstrainedSupply
		CREATE TABLE #TmpRefAdjAtmConstrainedSupply(
			EsdVersionId INT,
			SnOPDemandProductNm VARCHAR(100),
			YyyyMm int,
			YyyyQq int,
			AdjAtmConstrainedSupply float
		) 

		INSERT INTO #TmpRefAdjAtmConstrainedSupply(
			EsdVersionId 
			,SnOPDemandProductNm   
			,YyyyMm
			,YyyyQq
			,AdjAtmConstrainedSupply
		)


	SELECT  @EsdVersionId 
			,SnOPDemandProductNm
			,YyyyMm
			,YyyyQq
			,AdjAtmConstrainedSupply


		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
					--EsdVersionId INT,
					SnOPDemandProductNm VARCHAR(100),
					YyyyMm int,
					--YyyyQq int,
					AdjAtmConstrainedSupply float
			   ) T1
			JOIN (SELECT DISTINCT YearMonth, IntelYear*100+IntelQuarter AS YyyyQq FROM dbo.IntelCalendar) C
				ON T1.YyyyMm = C.YearMonth



EXEC sp_xml_removedocument @idoc
		--DELETE Rows where an Adjustment has been made, but then deleted
		DELETE  T1
		FROM [dbo].[EsdAdjAtmConstrainedSupply] T1
		JOIN [dbo].[SnOPDemandProductHierarchy] D 
		ON T1.[SnOPDemandProductId] = D.[SnOPDemandProductId]
		JOIN #TmpRefAdjAtmConstrainedSupply T2
			ON T2.EsdVersionId = T1.EsdVersionId
			AND T2.[SnOPDemandProductNm] = D.[SnOPDemandProductNm]
			AND T2.YyyyMm = T1.YearMm
		WHERE T2.AdjAtmConstrainedSupply IS NULL OR T2.AdjAtmConstrainedSupply = 0

		--UPDATE Rows that have already been eltered but the Quantity has changed
		UPDATE T1 
			SET T1.AdjAtmConstrainedSupply = CAST(T2.AdjAtmConstrainedSupply AS decimal(18,6))
		FROM [dbo].[EsdAdjAtmConstrainedSupply] T1
			JOIN [dbo].[SnOPDemandProductHierarchy] D 
		ON T1.[SnOPDemandProductId] = D.[SnOPDemandProductId]
		JOIN #TmpRefAdjAtmConstrainedSupply T2
			ON T2.EsdVersionId = T1.EsdVersionId
			AND T2.SnOPDemandProductNm = D.SnOPDemandProductNm
			AND T2.YyyyMm = T1.YearMm
		WHERE T2.AdjAtmConstrainedSupply <>0
		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
		INSERT INTO [dbo].[EsdAdjAtmConstrainedSupply]
				   (
						EsdVersionId 
						,[SnOPDemandProductId]   
						,YearMm
						,YearQq
						,AdjAtmConstrainedSupply
				   )

				SELECT EsdVersionId 
						,[SnOPDemandProductId]   
						,YyyyMm
						,YyyyQq
						,CAST(AdjAtmConstrainedSupply AS decimal(18,6))
				FROM #TmpRefAdjAtmConstrainedSupply T1
				JOIN [dbo].[SnOPDemandProductHierarchy] D 
					ON T1.SnOPDemandProductNm = D.SnOPDemandProductNm AND IsActive = 1
				WHERE NOT EXISTS (SELECT 1 FROM  [dbo].[EsdAdjAtmConstrainedSupply] T2 
				JOIN [dbo].[SnOPDemandProductHierarchy] D 
									ON T1.SnOPDemandProductNm = D.SnOPDemandProductNm
									WHERE T2.EsdVersionId = T1.EsdVersionId 
									AND T2.[SnOPDemandProductId] = D.[SnOPDemandProductId]
									AND T2.YearMm = T1.YyyyMm
									)
						AND T1.AdjAtmConstrainedSupply IS NOT NULL
						AND T1.AdjAtmConstrainedSupply <> 0 
END



