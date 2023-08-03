
CREATE   PROC [dbo].UspLoadMarketSegment

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from Market Segment
*************************************************************************************/
----    Date        User                    Description
----***************************************************************************-
----    2023-06-02  rmiralhx                Initial Release
----*********************************************************************************/
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadMarketSegment.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadMarketSegment Successful'
	DECLARE @Prog VARCHAR(255)
	DECLARE @SourceApplicationName VARCHAR(100) = 'Denodo'


	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadMarketSegment', 'UspLoadMarketSegment','Load daily data from Market Segment', 'BEGIN', NULL, @BatchId


		MERGE dbo.SnOPForecastMarketSegment AS TARGET 
		USING (SELECT [MarketSegmentId]
              , [MarketSegmentNm]
              ,[AllMarketSegmentId]
              ,[AllMarketSegmentNm]
              ,[MarketSegmentGroupNm]
              ,[ForecastMarketSegmentNm]
              ,[ActiveInd]
              ,[CreateDtm]
              ,[CreateUserNm]
              ,[LastUpdateUserDtm]
              ,[LastUpdateUserNm]
              ,[LastUpdateSystemUserDtm]
              ,[LastUpdateSystemUserNm]
              ,[CreatedOn]
              ,[CreatedBy]
		FROM dbo.StgForecastMarketSegment) AS SOURCE
		ON SOURCE.[MarketSegmentId] = TARGET.[MarketSegmentId]
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			   [MarketSegmentId]
              ,[MarketSegmentNm]
              ,[AllMarketSegmentId]
              ,[AllMarketSegmentNm]
              ,[MarketSegmentGroupNm]
              ,[ForecastMarketSegmentNm]
              ,[ActiveInd]
              ,[CreateDtm]
              ,[CreateUserNm]
              ,[LastUpdateUserDtm]
              ,[LastUpdateUserNm]
              ,[LastUpdateSystemUserDtm]
              ,[LastUpdateSystemUserNm])
	  VALUES (
              SOURCE.[MarketSegmentId]
              ,SOURCE.[MarketSegmentNm]
              ,SOURCE.[AllMarketSegmentId]
              ,SOURCE.[AllMarketSegmentNm]
              ,SOURCE.[MarketSegmentGroupNm]
              ,SOURCE.[ForecastMarketSegmentNm]
              ,SOURCE.[ActiveInd]
              ,SOURCE.[CreateDtm]
              ,SOURCE.[CreateUserNm]
              ,SOURCE.[LastUpdateUserDtm]
              ,SOURCE.[LastUpdateUserNm]
              ,SOURCE.[LastUpdateSystemUserDtm]
              ,SOURCE.[LastUpdateSystemUserNm])
		WHEN MATCHED THEN 
		UPDATE
			SET
			   TARGET.[MarketSegmentNm] = SOURCE.[MarketSegmentNm]
              ,TARGET.[AllMarketSegmentId] =  SOURCE.[AllMarketSegmentId]
              ,TARGET.[AllMarketSegmentNm] = SOURCE.[AllMarketSegmentNm]
              ,TARGET.[MarketSegmentGroupNm]  =  SOURCE.[MarketSegmentGroupNm]
              ,TARGET.[ForecastMarketSegmentNm] = SOURCE.[ForecastMarketSegmentNm]
              ,TARGET.[ActiveInd] = SOURCE.[ActiveInd]
              ,TARGET.[CreateDtm] = SOURCE.[CreateDtm]
              ,TARGET.[CreateUserNm] = SOURCE.[CreateUserNm]
              ,TARGET.[LastUpdateUserDtm] = SOURCE.[LastUpdateUserDtm]
              ,TARGET.[LastUpdateUserNm] = SOURCE.[LastUpdateUserNm]
              ,TARGET.[LastUpdateSystemUserDtm] = SOURCE.[LastUpdateSystemUserDtm]
              ,TARGET.[LastUpdateSystemUserNm] = SOURCE.[LastUpdateSystemUserNm]
              ,TARGET.[CreatedOn] = SOURCE.[CreatedOn]
              ,TARGET.[CreatedBy] = SOURCE.[CreatedBy]
		WHEN NOT MATCHED BY SOURCE THEN 
		UPDATE
			SET 
				TARGET.[ActiveInd] = 'N';
		
		--Logging End

		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadMarketSegment', 'UspLoadMarketSegment','Load daily data from Market Segment', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		--EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject= 'LoadMarketSegment Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadMarketSegment failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadMarketSegment Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadMarketSegment','UspLoadMarketSegment', 'Load daily data from Market Segment','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END

