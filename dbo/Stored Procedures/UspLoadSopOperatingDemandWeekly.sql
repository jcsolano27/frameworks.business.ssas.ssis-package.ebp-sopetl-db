
CREATE PROC [dbo].[UspLoadSopOperatingDemandWeekly]

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from Fab MPS for selected Versions
*************************************************************************************/
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadSopOperatingDemandWeekly.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadSopOperatingDemandWeekly Successful'
	DECLARE @Prog VARCHAR(255)
	DECLARE @SourceApplicationName VARCHAR(100) = 'Denodo'
	DECLARE @CONST_ParameterId_ConsensusDemand INT = [dbo].[CONST_ParameterId_ConsensusDemand]()
	DECLARE @CURRENT_WW INT

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSopOperatingDemandWeekly', 'UspLoadSopOperatingDemandWeekly','Load Weekly Demand Forecast data', 'BEGIN', NULL, @BatchId

		SELECT @CURRENT_WW = MAX(VersionNm) FROM dbo.StgSopOperatingDemandWeekly;
		DELETE FROM dbo.SopOperatingDemandWeekly WHERE SopOperatingDemandWeek = @CURRENT_WW;


		INSERT INTO dbo.SopOperatingDemandWeekly 
		SELECT 
			@SourceApplicationName SourceApplicationName,
			D.VersionNm SopOperatingDemandWeek, 
			H.SnOPDemandProductId,
			P.ProfitCenterCd,
			D.YearWw,
			SUM(Quantity) Quantity,
			GETDATE() CreatedOn,
			CURRENT_USER CreatedBy,
			MAX(DATEADD (ss , 1 , LastUpdateSystemDtm)) ModifiedOn 
		FROM
		dbo.StgSopOperatingDemandWeekly D
		JOIN
		[dbo].[StgProductHierarchy] H
		ON D.ProductNodeId = H.ProductNodeId
		JOIN [dbo].[StgProfitCenterHierarchy] P
		ON P.[ProfitCenterHierarchyId] = D.[ProfitCenterHierarchyId]
		GROUP BY 
			D.VersionNm, 
			H.SnOPDemandProductId,
			P.ProfitCenterCd,
			D.YearWw
		;


		--Logging End

		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSopOperatingDemandWeekly', 'UspLoadSopOperatingDemandWeekly','Load Weekly Demand Forecast data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		--EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject= 'LoadSopOperatingDemandWeekly Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadSopOperatingDemandWeekly failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadSopOperatingDemandWeekly Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSopOperatingDemandWeekly','UspLoadSopOperatingDemandWeekly', 'Load Demand Forecast data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END
