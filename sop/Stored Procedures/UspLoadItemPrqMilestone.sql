

CREATE     PROC [sop].[UspLoadItemPrqMilestone]

AS
----/*********************************************************************************
----    Purpose:        This proc is used to load data from AtlasIBI [V_RAWDATA_ATLAS_PRODUCT_MILESTONES] to SVD database   
----                    Source:      [dbo].[StgItemPrqMilestone]
----                    Destination: [sop].[ItemPrqMilestone]
----    Called by:      SSIS

----    Result sets:    None

----    Parameters        

----    Date        User            Description
----***************************************************************************-
----	2023-07-12	hmanentx		Initial Release
----*********************************************************************************/

BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'LoadItemPrqMilestones.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='LoadItemPrqMilestones Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC sop.UspAddApplicationLog 'Database', 'Info', 'LoadItemPrqMilestone', 'UspLoadItemPrqMilestone','Load ItemPrqMilestone Data', 'BEGIN', NULL, @BatchId

		MERGE sop.ItemPrqMilestone AS TARGET
		USING (
			SELECT
				PlanningSupplyPackageVariantId,
				SourceProjectNm,
				NpiInd,
				MilestoneTypeCd,
				PrqMilestoneDtm
			FROM (
				SELECT
					A.[SpeedId] AS PlanningSupplyPackageVariantId
					,A.[Project] AS SourceProjectNm
					,A.[Por]
					,A.[Trend]
					,A.[ActualFinish]
					,CASE WHEN Por <= GETDATE() THEN 0 ELSE 1 END AS NpiInd
				FROM [dbo].[StgItemPrqMilestone] AS A
				INNER JOIN (
					SELECT
						SpeedId
						,MAX(RowId) AS Max_RowId
					FROM [dbo].[StgItemPrqMilestone]
					GROUP BY SpeedId
				) AS M ON M.SpeedId = A.SpeedId AND M.Max_RowId = A.RowId
			) AS P
			UNPIVOT (PrqMilestoneDtm FOR MilestoneTypeCd IN ([Por], [Trend], [ActualFinish])) AS U
		) AS SOURCE
		ON
			SOURCE.PlanningSupplyPackageVariantId	= TARGET.PlanningSupplyPackageVariantId
			AND SOURCE.MilestoneTypeCd				= TARGET.MilestoneTypeCd COLLATE SQL_Latin1_General_CP1_CI_AS

		WHEN NOT MATCHED BY TARGET THEN
		INSERT
			(
				PlanningSupplyPackageVariantId
				,SourceProjectNm
				,MilestoneTypeCd
				,PrqMilestoneDtm
				,NpiInd
				,CreatedOnDtm
				,CreatedByNm
			)
		VALUES
			(
				Source.PlanningSupplyPackageVariantId
				,Source.SourceProjectNm
				,Source.MilestoneTypeCd
				,Source.PrqMilestoneDtm
				,Source.NpiInd
				,getutcdate()
				,original_login()
			)

		WHEN MATCHED THEN
		UPDATE SET 
			Target.SourceProjectNm	= Source.SourceProjectNm,
			Target.PrqMilestoneDtm	= Source.PrqMilestoneDtm,
			Target.NpiInd			= Source.NpiInd,
			Target.ModifiedOnDtm	= getutcdate(),
			Target.ModifiedByNm		= original_login();

		--Logging End
		EXEC sop.UspAddApplicationLog 'Database', 'Info', 'LoadItemPrqMilestone', 'UspLoadItemPrqMilestone','Load ItemPrqMilestone Data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC sop.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspLoadItemPrqMilestone Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadItemPrqMilestone failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC sop.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadItemPrqMilestone Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC sop.UspAddApplicationLog 'Database', 'Info', 'LoadItemPrqMilestone','UspLoadItemPrqMilestone', 'Load ItemPrqMilestone Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END

