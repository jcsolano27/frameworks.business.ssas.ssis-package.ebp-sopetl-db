CREATE PROC [dbo].[UspLoadBacklogSnapshot]

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from Fab MPS for selected Versions
*************************************************************************************/
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadBacklogSnapshot.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadBacklogSnapshot Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadBacklogSnapshot', 'UspLoadBacklogSnapshot','Load Demand Forecast data', 'BEGIN', NULL, @BatchId


		MERGE [dbo].[BacklogSnapshot] as T
		USING 
		(
			SELECT 
			'Hana' AS SourceApplicationName,
			I.[SnOPSupplyProductId] AS [SnapshotId],
			I.ItemName, 
			[YearWwNm] AS YearWw, 
			--ParameterId,
			SUM([NetConfirmedGoodsIssueBillingAllocationBacklogBillOfMaterialQty]) 'Quantity'
			FROM [dbo].[StgBAB] AS B
			join [dbo].[Items] AS I
			ON B.[ProductNodeId] = I.[ProductNodeId]
			/*join [dbo].[Parameters] P
			ON P.ParameterName = 'Backlog Snapshot'*/
			WHERE [NetConfirmedGoodsIssueBillingAllocationBacklogBillOfMaterialQty] IS NOT NULL
			GROUP BY I.[SnOPSupplyProductId],I.ItemName,[YearWwNm]--,ParameterId
		)
		AS S
		ON 	T.YearWw = S.YearWw
		AND T.[SnapshotId] = S.[SnapshotId]
		AND T.SourceApplicationName = S.SourceApplicationName
		WHEN NOT MATCHED BY Target THEN
			INSERT (SourceApplicationName,SnapshotId,ItemName,YearWw,Quantity)
			VALUES (S.SourceApplicationName,S.SnapshotId,S.ItemName,S.YearWw,S.Quantity)
		WHEN MATCHED THEN UPDATE SET
			T.[Quantity] = S.Quantity
		;
		
		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'ReconLoadActualData', 'UspMPSReconLoadActualData','Load BacklogSnapshot data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspMPSReconLoadActualData Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadBacklogSnapshot failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadBacklogSnapshot Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadBacklogSnapshot','UspLoadBacklogSnapshot', 'Load BacklogSnapshot data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END
