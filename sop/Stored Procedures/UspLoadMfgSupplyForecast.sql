
CREATE   PROCEDURE [sop].[UspLoadMfgSupplyForecast]
(
	@Debug BIT = 0
)

AS

/****************************************************************************************************
Purpose: Load sop.MfgSupplyForecast table using the Stage already loaded with OneMps and Compass Data
Main Tables:
	Source: sop.StgMfgSupplyResponseFe
	Destination: sop.MfgSupplyForecast

Called by: Etl/Agent Job

Result sets: None

Parameters:
	@Debug:
		0 = Do not output data
		1 = Will output some basic info
 
Return Codes:
		0 = Success
		< 0 = Error
		> 0 (No warnings for this SP, should never get a returncode > 0)
 
Exceptions: None expected

General approach:

To do:
 
	Date		User		Description
*********************************************************************************-
	2023-07-21	hmanentx	Initial Release
    2023-08-02	psillosx	Quantity is not null and <> 0
*********************************************************************************/

BEGIN

	SET NOCOUNT ON

	BEGIN TRY

		DECLARE @EmailMessage							VARCHAR(1000) = 'LoadMfgSupplyForecast Successful'
		DECLARE @Prog									VARCHAR(255)
		
		DECLARE @ReturnErrorMessage						VARCHAR(MAX)
		DECLARE @ErrorLoggedBy							VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		DECLARE @CurrentAction							VARCHAR(4000)
		DECLARE @DT										VARCHAR(50)  = SYSDATETIME()
		DECLARE @Message								VARCHAR(MAX)
		DECLARE @BatchId								VARCHAR(512)
		DECLARE @RowCount								INT

		--Logging Start
		SET @CurrentAction = @ErrorLoggedBy + ': SP Starting'
		SET @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + SYSTEM_USER
		EXEC sop.UspAddApplicationLog @LogSource = 'Database'
							  ,@LogType = 'Info'
							  ,@Category = 'Etl'
							  ,@SubCategory = @ErrorLoggedBy
							  ,@Message = @Message
							  ,@Status = 'BEGIN'
							  ,@Exception = NULL
							  ,@BatchId = @BatchId;

		-----------------------------------------------------------------------------------------------
		-- Start Work
		-----------------------------------------------------------------------------------------------

		-- VALIDATE ROW COUNT
		SELECT @RowCount = COUNT(1) FROM sop.StgMfgSupplyResponseFe

		IF @RowCount <> 0 BEGIN

			-- DECLARE VARIABLES
			DECLARE @CONST_SourceSystemId_Compass INT	= (SELECT sop.CONST_SourceSystemId_Compass())
			DECLARE @CONST_SourceSystemId_OneMps INT	= (SELECT sop.CONST_SourceSystemId_OneMps())

			--Determine the corresponding Compass ScenarioId that would have been run for the loaded content.
			DECLARE @ScenarioId INT = (
									SELECT DISTINCT ScenarioId
									FROM COMPASSPROD.Compass.dbo.DataSolveRun DSR
									WHERE RunId IN (SELECT TOP 1 SourceVersionId
													FROM sop.StgMfgSupplyResponseFe
													WHERE SourceSystemId = @CONST_SourceSystemId_Compass))

			-- Creating all the keys and all the references to insert.
			DROP TABLE IF EXISTS #AllKeys
			SELECT DISTINCT
				F.SourceSystemId,
				PlanningMonth,
				SourceVersionId,
				CAST(NULL AS VARCHAR(250)) AS DSI,
				W.WaferItemName AS SourceWaferItemName,
				W.SortItemName AS SourceSortItemName,
				Q.IntelYearQuarter
			INTO #AllKeys
			FROM sop.StgMfgSupplyResponseFe F
			CROSS JOIN 
				(
					SELECT DISTINCT
						SourceSystemId,
						WaferItemName,
						SortItemName
					FROM sop.StgMfgSupplyResponseFe
				) W
			CROSS JOIN 
				(
					SELECT DISTINCT
						SourceSystemId,
						IntelYearQuarter
					FROM sop.StgMfgSupplyResponseFe
				) Q
			WHERE
				W.SourceSystemId = F.SourceSystemId
				AND Q.SourceSystemId = F.SourceSystemId

			-- Updating SourceItem for Compass Items
			UPDATE K
			SET K.DSI = RI.SourceItem
			FROM #AllKeys K
			INNER JOIN COMPASSPROD.Compass.dbo.RefItems RI ON RI.ItemName = K.SourceWaferItemName
			WHERE K.SourceSystemId = @CONST_SourceSystemId_Compass

			-- Updating SourceItem for OneMps Items
			UPDATE K
			SET K.DSI = RI.SourceItem
			FROM #AllKeys K
			INNER JOIN
			(
				SELECT DISTINCT
					ItemId,
					SourceItem,
					SDAItemName
				FROM COMPASSPROD.Compass.dbo.VwSdaActiveItemMap
				WHERE ScenarioId = @ScenarioId
			) M
			ON M.SDAItemName = K.SourceWaferItemName
			INNER JOIN COMPASSPROD.Compass.dbo.RefItems RI ON RI.ItemId = M.ItemId
			WHERE
				K.SourceSystemId = @CONST_SourceSystemId_OneMps

			IF @Debug = 1 BEGIN
				SELECT COUNT(1) AS NullDSIs
				FROM #AllKeys
				WHERE DSI IS NULL
			END

			-- Summarizing the rows together and unpivoting for the final table
			DROP TABLE IF EXISTS #StorageTableInsert
			SELECT
				R.PlanningMonth,
				R.SourceVersionId,
				R.ItemHierarchy,
				R.ItemDescription,
				R.IntelYearQuarter,
				R.WaferOutQty
			INTO #StorageTableInsert
			FROM (
				SELECT
					AK.PlanningMonth,
					AK.SourceVersionId,
					'DSI' AS ItemHierarchy,
					AK.DSI AS ItemDescription,
					AK.IntelYearQuarter,
					SUM(FE.WaferOutQty) AS WaferOutQty
				FROM #AllKeys AK
				INNER JOIN sop.StgMfgSupplyResponseFe FE
					ON FE.PlanningMonth = AK.PlanningMonth
					AND FE.SourceVersionId = AK.SourceVersionId
					AND FE.WaferItemName = AK.SourceWaferItemName
					AND FE.SortItemName = AK.SourceSortItemName
					AND FE.IntelYearQuarter = AK.IntelYearQuarter
				GROUP BY
					AK.PlanningMonth,
					AK.SourceVersionId,
					AK.DSI,
					AK.IntelYearQuarter
				UNION
				SELECT
					AK.PlanningMonth,
					AK.SourceVersionId,
					'Sort UPI' AS ItemHierarchy,
					AK.SourceSortItemName,
					AK.IntelYearQuarter,
					SUM(FE.WaferOutQty) AS WaferOutQty
				FROM #AllKeys AK
				INNER JOIN sop.StgMfgSupplyResponseFe FE
					ON FE.PlanningMonth = AK.PlanningMonth
					AND FE.SourceVersionId = AK.SourceVersionId
					AND FE.WaferItemName = AK.SourceWaferItemName
					AND FE.SortItemName = AK.SourceSortItemName
					AND FE.IntelYearQuarter = AK.IntelYearQuarter
				GROUP BY
					AK.PlanningMonth,
					AK.SourceVersionId,
					AK.SourceSortItemName,
					AK.IntelYearQuarter
				UNION
				SELECT
					AK.PlanningMonth,
					AK.SourceVersionId,
					'Wafer UPI' AS ItemHierarchy,
					AK.SourceWaferItemName,
					AK.IntelYearQuarter,
					SUM(FE.WaferOutQty) AS WaferOutQty
				FROM #AllKeys AK
				INNER JOIN sop.StgMfgSupplyResponseFe FE
					ON FE.PlanningMonth = AK.PlanningMonth
					AND FE.SourceVersionId = AK.SourceVersionId
					AND FE.WaferItemName = AK.SourceWaferItemName
					AND FE.SortItemName = AK.SourceSortItemName
					AND FE.IntelYearQuarter = AK.IntelYearQuarter
				GROUP BY
					AK.PlanningMonth,
					AK.SourceVersionId,
					AK.SourceWaferItemName,
					AK.IntelYearQuarter
			) AS R

			-- Merge Final Data into the Storage Table
			MERGE sop.MfgSupplyForecast AS TARGET
			USING (
				SELECT
					PlanningMonth,
					PlanVersionId,
					CorridorId,
					ProductId,
					ProfitCenterCd,
					CustomerId,
					KeyFigureId,
					TimePeriodId,
					Quantity
				FROM(
					SELECT
						FE.PlanningMonth,
						PV.PlanVersionId,
						sop.CONST_CorridorId_NotApplicable() AS CorridorId,
						P.ProductId AS ProductId,
						sop.CONST_ProfitCenterCd_NotApplicable() AS ProfitCenterCd,
						sop.CONST_CustomerId_NotApplicable() AS CustomerId,
						sop.CONST_KeyFigureId_TmgfSupplyResponseVolumeFe() AS KeyFigureId,
						TP.TimePeriodId,
						SUM(FE.WaferOutQty) AS Quantity
					FROM #StorageTableInsert FE
					INNER JOIN dbo.EsdSourceVersions ESV	ON ESV.SourceVersionId = FE.SourceVersionId
					INNER JOIN sop.PlanVersion PV			ON PV.SourceVersionId = ESV.EsdVersionId AND PV.SourceSystemId = sop.CONST_SourceSystemId_Esd()
					INNER JOIN sop.TimePeriod TP			ON TP.FiscalYearQuarterNbr = FE.IntelYearQuarter AND TP.SourceNm = 'Quarter'
					INNER JOIN sop.Product P				ON P.SourceProductId = FE.ItemDescription
					GROUP BY
						FE.PlanningMonth,
						PV.PlanVersionId,
						TP.TimePeriodId,
						P.ProductId
				) AS GroupBy
				WHERE Quantity IS NOT NULL
					AND Quantity <> 0
			) AS SOURCE
			ON
				TARGET.PlanningMonthNbr		= SOURCE.PlanningMonth AND
				TARGET.PlanVersionId		= SOURCE.PlanVersionId AND
				TARGET.CorridorId			= SOURCE.CorridorId AND
				TARGET.ProductId			= SOURCE.ProductId AND
				TARGET.ProfitCenterCd		= SOURCE.ProfitCenterCd AND
				TARGET.CustomerId			= SOURCE.CustomerId AND
				TARGET.KeyFigureId			= SOURCE.KeyFigureId AND
				TARGET.TimePeriodId			= SOURCE.TimePeriodId
			WHEN MATCHED THEN
				UPDATE SET
					TARGET.Quantity			= SOURCE.Quantity,
					TARGET.ModifiedOnDtm	= GETUTCDATE(),
					TARGET.ModifiedByNm		= ORIGINAL_LOGIN()
			WHEN NOT MATCHED BY TARGET THEN
				INSERT
				(
					PlanningMonthNbr
					,PlanVersionId
					,CorridorId
					,ProductId
					,ProfitCenterCd
					,CustomerId
					,KeyFigureId
					,TimePeriodId
					,Quantity
					,CreatedOnDtm
					,CreatedByNm
				)
				VALUES
				(
					SOURCE.PlanningMonth
					,SOURCE.PlanVersionId
					,SOURCE.CorridorId
					,SOURCE.ProductId
					,SOURCE.ProfitCenterCd
					,SOURCE.CustomerId
					,SOURCE.KeyFigureId
					,SOURCE.TimePeriodId
					,SOURCE.Quantity
					,GETUTCDATE()
					,ORIGINAL_LOGIN()
				);

		END

		--Logging End
		SET @CurrentAction = @ErrorLoggedBy + ': SP Finishing'
		SET @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN()
		EXEC sop.UspAddApplicationLog @LogSource = 'Database'
							  ,@LogType = 'Info'
							  ,@Category = 'Etl'
							  ,@SubCategory = @ErrorLoggedBy
							  ,@Message = @Message
							  ,@Status = 'END'
							  ,@Exception = NULL
							  ,@BatchId = @BatchId;

		--Send sucess email to MPS Recon support PDL
		EXEC [sop].[UspMPSReconSendEmail] @EmailBody = @EmailMessage,@EmailSubject = '[sop].[UspLoadMfgSupplyForecast] Successful'

	END TRY

	BEGIN CATCH

		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='UspLoadMfgSupplyForecast failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC sop.UspMPSReconSendEmail @EmailBody = @EmailMessage,@EmailSubject = '[sop].[UspLoadMfgSupplyForecast] Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX) = ERROR_MESSAGE()
		
		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Error'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @CurrentAction
		  , @Status = 'ERROR'
		  , @Exception = @ErrorMsg
		  , @BatchId = @BatchId;

		RAISERROR(@ErrorMsg, 16, 1)

	END CATCH

	SET NOCOUNT OFF

END
