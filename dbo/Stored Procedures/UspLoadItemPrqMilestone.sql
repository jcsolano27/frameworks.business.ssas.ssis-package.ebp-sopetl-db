

CREATE   PROC [dbo].[UspLoadItemPrqMilestone]

AS
----/*********************************************************************************
----    Purpose:        This proc is used to load data from AtlasIBI [V_RAWDATA_ATLAS_PRODUCT_MILESTONES] to SVD database   
----                    Source:      [dbo].[StgItemPrqMilestone]
----                    Destination: [dbo].[ItemPrqMilestone]
----    Called by:      SSIS

----    Result sets:    None

----    Parameters        

----    Date        User            Description
----***************************************************************************-
----    2023-05-15                  Initial Release
----	2023-07-27	atairumx		Changed columns CreatedOn/CreatedBy to MofifiedOn/ModifiedBy in MERGE UPDATE 
----*********************************************************************************/

BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadItemPrqMilestones.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadItemPrqMilestones Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadItemPrqMilestone', 'UspLoadItemPrqMilestone','Load ItemPrqMilestone Data', 'BEGIN', NULL, @BatchId

				MERGE dbo.ItemPrqMilestone AS TARGET
		USING (
				SELECT A.[BulkId]
					  ,A.[RowId]
					  ,A.[InsDtm]
					  ,A.[InstcNm]
					  ,A.[SpeedId]
					  ,A.[Project]
					  ,A.[MilestoneUid]
					  ,A.[Milestone]
					  ,A.[MilestoneBase]
					  ,A.[PlcOrder]
					  ,A.[Importance]
					  ,A.[Por]
					  ,CASE WHEN Por <= GETDATE() THEN 'No Npi' ELSE 'Npi' END AS NpiFlag
				  FROM [SVD].[dbo].[StgItemPrqMilestone] AS A
				  INNER JOIN (
					 SELECT max(RowId) as MaxRowId,SpeedId AS SpeedID
					 FROM [SVD].[dbo].[StgItemPrqMilestone]
					 GROUP BY SpeedId
							 ) AS B
				ON A.RowId = B.MaxRowId AND A.SpeedId = B.SpeedID
		) AS SOURCE
		ON SOURCE.SpeedId = TARGET.SpeedId
		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
					   [BulkId]
					  ,[RowId]
					  ,[InsDtm]
					  ,[InstcNm]
					  ,[SpeedId]
					  ,[Project]
					  ,[MilestoneUid]
					  ,[Milestone]
					  ,[MilestoneBase]
					  ,[PlcOrder]
					  ,[Importance]
					  ,[Por]
					  ,[NpiFlag]
					  ,[CreatedOn]
                      ,[CreatedBy]
				)

		VALUES (
					   SOURCE.[BulkId]
					  ,SOURCE.[RowId]
					  ,SOURCE.[InsDtm]
					  ,SOURCE.[InstcNm]
					  ,SOURCE.[SpeedId]
					  ,SOURCE.[Project]
					  ,SOURCE.[MilestoneUid]
					  ,SOURCE.[Milestone]
					  ,SOURCE.[MilestoneBase]
					  ,SOURCE.[PlcOrder]
					  ,SOURCE.[Importance]
					  ,SOURCE.[Por]
					  ,SOURCE.[NpiFlag]
					  ,GETDATE() 
					  ,SESSION_USER
		)
		WHEN MATCHED THEN 
		UPDATE SET 
					   TARGET.[BulkId] = SOURCE.[BulkId]
					  ,TARGET.[RowId] = SOURCE.[RowId]
					  ,TARGET.[InsDtm] = SOURCE.[InsDtm]
					  ,TARGET.[InstcNm] = SOURCE.[InstcNm]
					  ,TARGET.[SpeedId] = SOURCE.[SpeedId]
					  ,TARGET.[Project] = SOURCE.[Project]
					  ,TARGET.[MilestoneUid] = SOURCE.[MilestoneUid]
					  ,TARGET.[Milestone] = SOURCE.[Milestone]
					  ,TARGET.[MilestoneBase] = SOURCE.[MilestoneBase]
					  ,TARGET.[PlcOrder] = SOURCE.[PlcOrder]
					  ,TARGET.[Importance] = SOURCE.[Importance]
					  ,TARGET.[Por] = SOURCE.[Por]
					  ,TARGET.[NpiFlag] = SOURCE.[NpiFlag]
					  ,TARGET.[ModifiedOn] = GETDATE()
					  ,TARGET.[ModifiedBy] = SESSION_USER;

		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadItemPrqMilestone', 'UspLoadItemPrqMilestone','Load ItemPrqMilestone Data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspLoadItemPrqMilestone Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadItemPrqMilestone failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadItemPrqMilestone Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadItemPrqMilestone','UspLoadItemPrqMilestone', 'Load ItemPrqMilestone Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END









