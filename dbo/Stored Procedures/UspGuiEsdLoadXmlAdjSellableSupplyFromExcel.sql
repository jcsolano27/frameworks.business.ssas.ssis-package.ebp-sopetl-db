




CREATE PROC [dbo].[UspGuiEsdLoadXmlAdjSellableSupplyFromExcel] (@xmlString TEXT,@LoadedByTool varchar(25),@EsdVersionId int)
AS
/****************************************************************************************
DESCRIPTION: This proc loads Wspw Historical Wafer starts from AIR. It runs on Recon DB server.
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS

	dbo.[UspGuiEsdLoadXmlAdjSellableSupplyFromExcel]	 @xmlString = '<list><record><SnOPDemandProductNm>A-Gold 620T BGA</SnOPDemandProductNm><YyyyMm>202212</YyyyMm><AdjSellableSupply>5</AdjSellableSupply></record></list>' ,@LoadedByTool='ESU_POC',@EsdVersionId = 111

	DECLARE @xmlString VARCHAR(MAX) = '<list><record><SnOPDemandProductNm>A-Gold 620T BGA</SnOPDemandProductNm><YyyyMm>202212</YyyyMm><AdjSellableSupply>5</AdjSellableSupply></record></list>'
DECLARE @LoadedByTool varchar(25) ='ESU_POC'
DECLARE @EsdVersionId INT = 111

-- TEST HARNESS */



 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString


		IF OBJECT_ID('tempdb..#TmpRefAdjSellableSupply') IS NOT NULL drop table #TmpRefAdjSellableSupply
		CREATE TABLE #TmpRefAdjSellableSupply(
			EsdVersionId INT,
			SnOPDemandProductNm VARCHAR(100),
			YyyyMm int,
			YyyyQq int,
			AdjSellableSupply float
		) 

		INSERT INTO #TmpRefAdjSellableSupply(
			EsdVersionId 			,SnOPDemandProductNm   
			,YyyyMm
			,YyyyQq
			,AdjSellableSupply
		)


	SELECT @EsdVersionId 
			,SnOPDemandProductNm   
			,YyyyMm
			,YyyyQq
			,AdjSellableSupply


		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
					--EsdVersionId INT,
					SnOPDemandProductNm VARCHAR(100),
					YyyyMm int,
					--YyyyQq int,
					AdjSellableSupply float
			   ) T1
			JOIN (SELECT DISTINCT YearMonth, IntelYear*100+IntelQuarter AS YyyyQq FROM dbo.IntelCalendar) C
				ON T1.YyyyMm = C.YearMonth



EXEC sp_xml_removedocument @idoc

--select * from #TmpRefAdjSellableSupply

		--DELETE Rows where an Adjustment has been made, but then deleted
		DELETE  T1
		FROM [dbo].[EsdAdjSellableSupply] T1
		JOIN [dbo].[SnOPDemandProductHierarchy] D 
		ON T1.[SnOPDemandProductId] = D.[SnOPDemandProductId]
		JOIN #TmpRefAdjSellableSupply T2
			ON T2.EsdVersionId = T1.EsdVersionId
			AND T2.[SnOPDemandProductNm] = D.[SnOPDemandProductNm]
			AND T2.YyyyMm = T1.YearMm
			AND D.IsActive = 1

		WHERE T2.AdjSellableSupply IS NULL OR T2.AdjSellableSupply = 0

		--UPDATE Rows that have already been altered but the Quantity has changed
		UPDATE T1 
			SET T1.AdjSellableSupply = CAST(T2.AdjSellableSupply AS DECIMAL(18,6))
		FROM [dbo].[EsdAdjSellableSupply] T1
			JOIN [dbo].[SnOPDemandProductHierarchy] D 
		ON T1.[SnOPDemandProductId] = D.[SnOPDemandProductId]
		JOIN #TmpRefAdjSellableSupply T2
			ON T2.EsdVersionId = T1.EsdVersionId
			AND T2.SnOPDemandProductNm = D.SnOPDemandProductNm
			AND T2.YyyyMm = T1.YearMm
			AND D.IsActive = 1
		WHERE T2.AdjSellableSupply <>0

		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
		INSERT INTO [dbo].[EsdAdjSellableSupply]
				   (
						EsdVersionId 
						,[SnOPDemandProductId]   
						,YearMm
						,YearQq
						,AdjSellableSupply
				   )

				SELECT EsdVersionId 
						,[SnOPDemandProductId]
						,YyyyMm
						,YyyyQq
						,CAST(AdjSellableSupply AS DECIMAL(18,6))
				FROM #TmpRefAdjSellableSupply T1
					JOIN [dbo].[SnOPDemandProductHierarchy] D 
					ON T1.SnOPDemandProductNm = D.SnOPDemandProductNm
					AND D.IsActive = 1

				WHERE NOT EXISTS (SELECT 1 FROM  [dbo].[EsdAdjSellableSupply] T2 
										JOIN [dbo].[SnOPDemandProductHierarchy] D 
									ON T1.SnOPDemandProductNm = D.SnOPDemandProductNm
									WHERE T2.EsdVersionId = T1.EsdVersionId 
									AND T2.[SnOPDemandProductId] = D.[SnOPDemandProductId]
									AND T2.YearMm = T1.YyyyMm
									)
						AND T1.AdjSellableSupply IS NOT NULL
						AND T1.AdjSellableSupply <> 0
END




