CREATE   PROC [dbo].[UspLoadSalesChannelHierarchy]

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from Sales Channel Hierarchy
*************************************************************************************/
----    Date        User                    Description
----***************************************************************************-
----    2023-05-26  rmiralhx                Initial Release
----*********************************************************************************/
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadSalesChannelHierarchy.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadSalesChannelHierarchy Successful'
	DECLARE @Prog VARCHAR(255)
	DECLARE @SourceApplicationName VARCHAR(100) = 'Denodo'
	DECLARE @CONST_ParameterId_ConsensusDemand INT = [dbo].[CONST_ParameterId_ConsensusDemand]()
	DECLARE @CURRENT_WW INT

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSalesChannelHierarchy', 'UspLoadLoadSalesChannelHierarchy','Load daily data from Sales Channel Hierarchy', 'BEGIN', NULL, @BatchId


		MERGE dbo.SnOPSalesChannelHierarchy AS TARGET 
		USING (SELECT DISTINCT [HierarchyLevelId]
				  ,[SalesChannelId]
				  ,[ChannelNodeId]
				  ,[SourceNm]
				  ,[AllSalesChannelId]
				  ,[AllSalesChannelNm]
				  ,[DistributionChannelCd]
				  ,[SalesChannelNm]
				  ,[DistributionChannelId]
				  ,[ActiveInd]
				  ,[LastUpdateUserNm]
				  ,[LastUpdateUserDtm]
				  ,[LastUpdateSystemUserDtm]
				  ,[LastUpdateSystemUserNm]
				  ,[CreateDtm]
				  ,[CreateUserNm]
				  ,[LastLoadDtm]
				  ,[SalesChannelLastLoadDtm]
		FROM dbo.StgSalesChannel) AS SOURCE
		ON SOURCE.HierarchyLevelId = TARGET.HierarchyLevelId AND
		   SOURCE.SalesChannelId = TARGET.SalesChannelId AND
		   SOURCE.ChannelNodeId = TARGET.ChannelNodeId AND
		   SOURCE.SourceNm = TARGET.SourceNm AND
		   SOURCE.ActiveInd = TARGET.ActiveInd
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
			[HierarchyLevelId]
			  ,[SalesChannelId]
			  ,[ChannelNodeId]
			  ,[SourceNm]
			  ,[AllSalesChannelId]
			  ,[AllSalesChannelNm]
			  ,[DistributionChannelCd]
			  ,[SalesChannelNm]
			  ,[DistributionChannelId]
			  ,[ActiveInd]
			  ,[LastUpdateUserNm]
			  ,[LastUpdateUserDtm]
			  ,[LastUpdateSystemUserDtm]
			  ,[LastUpdateSystemUserNm]
			  ,[CreateDtm]
			  ,[CreateUserNm]
			  ,[LastLoadDtm]
			  ,[SalesChannelLastLoadDtm])
	  VALUES (
			SOURCE.[HierarchyLevelId]
			,SOURCE.[SalesChannelId]
			,SOURCE.[ChannelNodeId]
			,SOURCE.[SourceNm]
			,SOURCE.[AllSalesChannelId]
			,SOURCE.[AllSalesChannelNm]
			,SOURCE.[DistributionChannelCd]
			,SOURCE.[SalesChannelNm]
			,SOURCE.[DistributionChannelId]
			,SOURCE.[ActiveInd]
			,SOURCE.[LastUpdateUserNm]
			,SOURCE.[LastUpdateUserDtm]
			,SOURCE.[LastUpdateSystemUserDtm]
			,SOURCE.[LastUpdateSystemUserNm]
			,SOURCE.[CreateDtm]
			,SOURCE.[CreateUserNm]
			,SOURCE.[LastLoadDtm]
			,SOURCE.[SalesChannelLastLoadDtm])
		WHEN MATCHED THEN 
		UPDATE
			SET
			  TARGET.[HierarchyLevelId] = SOURCE.[HierarchyLevelId],
			  TARGET.[SalesChannelId] = SOURCE.[SalesChannelId],
			  TARGET.[ChannelNodeId] = SOURCE.[ChannelNodeId],
			  TARGET.[SourceNm] = SOURCE.[SourceNm],
			  TARGET.[AllSalesChannelId] = SOURCE.[AllSalesChannelId],
			  TARGET.[AllSalesChannelNm] = SOURCE.[AllSalesChannelNm],
			  TARGET.[DistributionChannelCd] = SOURCE.[DistributionChannelCd],
			  TARGET.[SalesChannelNm] = SOURCE.[SalesChannelNm],
			  TARGET.[DistributionChannelId] = SOURCE.[DistributionChannelId],
			  TARGET.[ActiveInd] = SOURCE.[ActiveInd],
			  TARGET.[LastUpdateUserNm] = SOURCE.[LastUpdateUserNm],
			  TARGET.[LastUpdateUserDtm] = SOURCE.[LastUpdateUserDtm],
			  TARGET.[LastUpdateSystemUserDtm] = SOURCE.[LastUpdateSystemUserDtm],
			  TARGET.[LastUpdateSystemUserNm] = SOURCE.[LastUpdateSystemUserNm],
			  TARGET.[CreateDtm] = SOURCE.[CreateDtm],
			  TARGET.[CreateUserNm] = SOURCE.[CreateUserNm],
			  TARGET.[LastLoadDtm] = SOURCE.[LastLoadDtm],
			  TARGET.[SalesChannelLastLoadDtm] = SOURCE.[SalesChannelLastLoadDtm]
		WHEN NOT MATCHED BY SOURCE THEN 
		UPDATE
			SET 
				TARGET.[ActiveInd] = 'N';
		
		--Logging End

		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSalesChannelHierarchy', 'UspLoadLoadSalesChannelHierarchy','Load daily data from Sales Channel Hierarchy', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		--EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject= 'LoadSalesChannelHierarchy Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadSalesChannelHierarchy failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadSalesChannelHierarchy Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSalesChannelHierarchy','UspLoadLoadSalesChannelHierarchy', 'Load daily data from Sales Channel Hierarchy','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END

--COMMIT
--ROLLBACK