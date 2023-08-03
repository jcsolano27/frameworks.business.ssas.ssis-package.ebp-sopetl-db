





CREATE PROC [dbo].[UspGuiEsdLoadXmlAdjDemandFromExcel] (@xmlString TEXT,@LoadedByTool varchar(25),@EsdVersionId int)
AS
/****************************************************************************************
DESCRIPTION: This proc loads Wspw Historical Wafer starts from AIR. It runs on Recon DB server.
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [esd].[UspLoadXMLAdjDemandFromExcel]	
	-- TEST HARNESS */
 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50),
		@ProfitCenterAdj				int
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER

SET @ProfitCenterAdj = (SELECT ProfitCenterId FROM [dbo].[GuiUIDemandProfitCenter])

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString


		IF OBJECT_ID('tempdb..#TmpRefAdjDemand') IS NOT NULL drop table #TmpRefAdjDemand
		CREATE TABLE #TmpRefAdjDemand(
			EsdVersionId INT,
			SnOPDemandProductNm VARCHAR(100),
			YyyyMm int,
			YyyyQq int,
			AdjDemand float
		) 

		INSERT INTO #TmpRefAdjDemand(
			EsdVersionId 
			,SnOPDemandProductNm   
			,YyyyMm
			,YyyyQq
			,AdjDemand
		)


	SELECT  @EsdVersionId 
			,SnOPDemandProductNm
			,YyyyMm
			,YyyyQq
			,AdjDemand


		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
					--EsdVersionId INT,
					SnOPDemandProductNm VARCHAR(100),
					YyyyMm int,
					--YyyyQq int,
					AdjDemand float
			   ) T1
			JOIN (SELECT DISTINCT YearMonth, IntelYear*100+IntelQuarter AS YyyyQq FROM dbo.IntelCalendar) C
				ON T1.YyyyMm = C.YearMonth



EXEC sp_xml_removedocument @idoc
		--DELETE Rows where an Adjustment has been made, but then deleted
		DELETE  T1
		FROM [dbo].[EsdAdjDemand] T1
		JOIN [dbo].[SnOPDemandProductHierarchy] D 
		ON T1.[SnOPDemandProductId] = D.[SnOPDemandProductId]
		JOIN #TmpRefAdjDemand T2
			ON T2.EsdVersionId = T1.EsdVersionId
			AND T2.[SnOPDemandProductNm] = D.[SnOPDemandProductNm]
			AND T2.YyyyMm = T1.YearMm
			WHERE T2.AdjDemand IS NULL OR T2.AdjDemand = 0 and T1.ProfitCenterCd = @ProfitCenterAdj

		--UPDATE Rows that have already been eltered but the Quantity has changed
		UPDATE T1 
			SET T1.AdjDemand = CAST(T2.AdjDemand AS decimal(18,6))
		FROM [dbo].[EsdAdjDemand] T1
			JOIN [dbo].[SnOPDemandProductHierarchy] D 
		ON T1.[SnOPDemandProductId] = D.[SnOPDemandProductId]
		JOIN #TmpRefAdjDemand T2
			ON T2.EsdVersionId = T1.EsdVersionId
			AND T2.SnOPDemandProductNm = D.SnOPDemandProductNm
			AND T2.YyyyMm = T1.YearMm
		WHERE T2.AdjDemand <>0 and T1.ProfitCenterCd = @ProfitCenterAdj

		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
		INSERT INTO [dbo].[EsdAdjDemand]
				   (
						EsdVersionId 
						,[SnOPDemandProductId]   
						,YearMm
						,ProfitCenterCd
						,YearQq
						,AdjDemand
				   )

				SELECT EsdVersionId 
						,[SnOPDemandProductId]   
						,YyyyMm
						,@ProfitCenterAdj
						,YyyyQq
						,CAST(AdjDemand AS decimal(18,6))
				FROM #TmpRefAdjDemand T1
					JOIN [dbo].[SnOPDemandProductHierarchy] D 
					ON T1.SnOPDemandProductNm = D.SnOPDemandProductNm AND IsActive = 1
				WHERE NOT EXISTS (SELECT 1 FROM  [dbo].[EsdAdjDemand] T2 
										JOIN [dbo].[SnOPDemandProductHierarchy] D 
									ON T1.SnOPDemandProductNm = D.SnOPDemandProductNm
									WHERE T2.EsdVersionId = T1.EsdVersionId 
									AND T2.[SnOPDemandProductId] = D.[SnOPDemandProductId]
									AND T2.YearMm = T1.YyyyMm
									and T2.ProfitCenterCd = @ProfitCenterAdj
									)
						AND T1.AdjDemand IS NOT NULL
						AND T1.AdjDemand <> 0 
END




