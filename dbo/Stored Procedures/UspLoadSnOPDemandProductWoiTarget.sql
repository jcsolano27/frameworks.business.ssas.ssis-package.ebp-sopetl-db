
CREATE   PROC [dbo].[UspLoadSnOPDemandProductWoiTarget] (@TableType varchar(100))
AS 

/************************************************************************************ 
DESCRIPTION: This proc is used to load data from HANA to SnOP Demand Product WOI Target 
*************************************************************************************/ 

BEGIN

----/*********************************************************************************
     
----    Purpose: Loads data from product sources to the WOI Target destination.
----    Sources: [dbo].[StgHdmrTargetSupply] / [dbo].[StgNonHdmrProducts] / [dbo].[StgCompassMeasure]
----    Destinations: [dbo].[SnOPDemandProductWoiTarget]

----    Called by:      SSIS
         
----    Result sets:    None
     
----    Parameters:
----                    @TableType:
----                        HDMR - Loads data from HDMR Products
----                        NONHDMR - Loads data from Non-HDMR Products
----                        COMPASS - Loads data from Compass Measures
         
----    Return Codes:   0 = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-06-06  hmanentx        Initial Release
----    2023-06-27  hmanentx        NonHdmr changes in Join (ProductNm for ProductId)

----*********************************************************************************/
	SET NOCOUNT ON

	/*
	EXEC [dbo].[UspLoadSnOPDemandProductWoiTarget] @TableType = 'COMPASS'
	SELECT * FROM [dbo].[SnOPDemandProductWoiTarget]
	*/

    BEGIN TRY

		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
		  , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		  , @CurrentAction      VARCHAR(4000)
		  , @DT                 VARCHAR(50)  = SYSDATETIME()
		  , @Message            VARCHAR(MAX)
		  , @BatchId			VARCHAR(512)

		SET @CurrentAction = @ErrorLoggedBy + ': SP Starting'

		SET @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN()

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Info'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @Message
		  , @Status = 'BEGIN'
		  , @Exception = NULL
		  , @BatchId = @BatchId;

		------> Create Variables
		DECLARE
			@CONST_SourceApplicationId_Hana			INT = [dbo].[CONST_SourceApplicationId_Hana]()
			,@CONST_SourceApplicationId_Compass		INT = [dbo].[CONST_SourceApplicationId_Compass]()
			,@CONST_ParameterId_TargetSupply		INT = [dbo].[CONST_ParameterId_TargetSupply]()
			,@CONST_SvdSourceApplicationId_Hdmr		INT = [dbo].[CONST_SvdSourceApplicationId_Hdmr]()
			,@CONST_SvdSourceApplicationId_NonHdmr	INT = [dbo].[CONST_SvdSourceApplicationId_NonHdmr]()
			,@CONST_SvdSourceApplicationId_Esd		INT = [dbo].[CONST_SvdSourceApplicationId_Esd]()
			,@Counter								INT
			,@CounterLimit							INT
 
		DECLARE @SnOPDemandProductWoiTarget TABLE
		( 
			PlanningMonth				INT
			,SourceApplicationId		INT
			,SvdSourceApplicationId		INT
			,SourceVersionId			INT
			,SnOPDemandProductId		INT
			,YearWw						INT
			,Quantity					FLOAT
			,PRIMARY KEY(PlanningMonth, SourceApplicationId, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw)
		)

		IF @TableType = 'HDMR' BEGIN -- HDMR Product Metrics

			DECLARE @HDMRTemp TABLE
			( 
				PlanningMonth				INT
				,SourceApplicationId		INT
				,SvdSourceApplicationId		INT
				,SourceVersionId			INT
				,SnOPDemandProductId		INT
				,YearWw						INT
				,Quantity					FLOAT
				,PRIMARY KEY(PlanningMonth, SourceApplicationId, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw)
			)

			------> HDMR
			INSERT INTO @HDMRTemp
			SELECT 
				HS.PlanningMonth
				,@CONST_SourceApplicationId_Hana as SourceApplicationId
				,@CONST_SvdSourceApplicationId_Hdmr as SvdSourceApplicationId
				,HS.SourceVersionId
				,P.SnOPDemandProductId
				,IC.YearWw AS YearWw
				,WOIT.ParameterQty Quantity
			FROM [dbo].[StgHdmrTargetSupply] WOIT 
			INNER JOIN dbo.IntelCalendar IC ON IC.YearQq = WOIT.FiscalYearQuarterNbr
			INNER JOIN dbo.StgProductHierarchy P ON WOIT.ProductNodeId = P.ProductNodeId 
			INNER JOIN [dbo].[HdmrSnapshot] HS ON HS.SourceVersionId = WOIT.SnapshotId 
			WHERE
				WOIT.ParameterTypeNm = 'Target WOI'
				AND WOIT.ParameterQty <> 0

			-- Remove the Compass data that can be concurring with the same keys as the HDMR data
			--DELETE FROM T
			--FROM [dbo].[SnOPDemandProductWoiTarget] T
			--INNER JOIN @HDMRTemp S
			--	ON T.PlanningMonth = S.PlanningMonth
			--	AND T.SnOPDemandProductId = S.SnOPDemandProductId
			--	AND T.YearWw = S.YearWw
			--	AND T.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd

			------> Merge all the HDMR data into the main temp table
			INSERT INTO @SnOPDemandProductWoiTarget
			SELECT
				PlanningMonth
				,SourceApplicationId
				,SvdSourceApplicationId
				,SourceVersionId
				,SnOPDemandProductId
				,YearWw
				,Quantity
			FROM @HDMRTemp

		END
		ELSE IF @TableType = 'NONHDMR' BEGIN -- Non-HDMR Product Metrics

			DECLARE @NonHdmrTemp TABLE
			(
				PlanningMonth				INT
				,SourceApplicationId		INT
				,SvdSourceApplicationId		INT
				,SourceVersionId			VARCHAR(30)
				,SnOPDemandProductId		INT
				,YearWw						INT
				,Quantity					FLOAT
				,PRIMARY KEY(PlanningMonth, SourceApplicationId, SvdSourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw)
			)

			DECLARE @SourceVersionList TABLE
			(
				Id					INT
				,SourceVersion		VARCHAR(30)
			)

			------> Non HDMR Products
			INSERT INTO @NonHdmrTemp
			SELECT
				PlanningMonth
				,SourceApplicationId
				,SvdSourceApplicationId
				,SourceVersionId
				,SnOPDemandProductId
				,YearWw
				,Quantity
			FROM
			(
				SELECT
					NHdmr.PlanningFiscalYearMonthNbr AS PlanningMonth
					,NHdmr.QuarterFiscalYearNbr
					,@CONST_SourceApplicationId_Hana as SourceApplicationId
					,@CONST_SvdSourceApplicationId_NonHdmr AS SvdSourceApplicationId
					,DP.SnOPDemandProductId
					,IC.YearWw
					,NHdmr.FullBuildTargetWOIQty AS FullBuildTargetWOIQty
					,NHdmr.DieBuildTargetWOIQty AS DieBuildTargetWOIQty
					,NHdmr.SubstrateBuildTargetWOIQty AS SubstrateBuildTargetWOIQty
				FROM [dbo].StgNonHdmrProducts NHdmr
				INNER JOIN [dbo].[SnOPDemandProductHierarchy] DP ON DP.SnOPDemandProductId = NHdmr.SnOPDemandProductId /*TEMPORARY*/
				INNER JOIN dbo.IntelCalendar IC ON IC.YearQq = NHdmr.QuarterFiscalYearNbr
				WHERE
					(
						NHdmr.FullBuildTargetWOIQty <> 0
						AND NHdmr.DieBuildTargetWOIQty <> 0
						AND NHdmr.SubstrateBuildTargetWOIQty <> 0
					)
					AND ISNUMERIC(NHdmr.QuarterFiscalYearNbr) = 1
			) P
			UNPIVOT
			(Quantity FOR SourceVersionId IN (FullBuildTargetWOIQty,DieBuildTargetWOIQty,SubstrateBuildTargetWOIQty)
			) AS UNPVT

			SET @Counter = 1
			SET @CounterLimit = (SELECT COUNT(DISTINCT SourceVersionId) FROM @NonHdmrTemp)

			INSERT INTO @SourceVersionList
			SELECT RANK() OVER (ORDER BY SourceVersionId ASC) Id, SourceVersionId FROM @NonHdmrTemp GROUP BY SourceVersionId

			WHILE (@Counter <= @CounterLimit)
			BEGIN
				UPDATE NHDMR
				SET NHDMR.SourceVersionId = List.Id
				FROM @NonHdmrTemp NHDMR
				INNER JOIN @SourceVersionList List ON List.Id = @Counter AND List.SourceVersion = NHDMR.SourceVersionId COLLATE SQL_Latin1_General_CP1_CI_AS

				SET @Counter = @Counter + 1
			END

			-- Remove the Compass data that can be concurring with the same keys as the NON-HDMR data
			--DELETE FROM T
			--FROM [dbo].[SnOPDemandProductWoiTarget] T
			--INNER JOIN @NonHdmrTemp S
			--	ON T.PlanningMonth = S.PlanningMonth
			--	AND T.SnOPDemandProductId = S.SnOPDemandProductId
			--	AND T.YearWw = S.YearWw
			--	AND T.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd

			------> Merge all the Non HDMR data into the main temp table
			INSERT INTO @SnOPDemandProductWoiTarget
			SELECT
				PlanningMonth
				,SourceApplicationId
				,SvdSourceApplicationId
				,SourceVersionId
				,SnOPDemandProductId
				,YearWw
				,Quantity
			FROM @NonHdmrTemp

		END
		ELSE BEGIN -- Compass Measures

			DECLARE @CompassMeasures TABLE
			(
				PlanningMonth				INT
				,SourceApplicationId		INT
				,SvdSourceApplicationId		INT
				,PublishLogId				INT
				,SnOPDemandProductId		INT
				,YearWw						INT
				,MeasureQty					FLOAT
				,PRIMARY KEY(PlanningMonth, SourceApplicationId, SvdSourceApplicationId, PublishLogId, SnOPDemandProductId, YearWw)
			)

			------> Compass Measures
			;WITH CTE_EsdSourceVersions AS
			(
				SELECT
					SourceVersionId
					,MAX(EsdVersionId) AS EsdVersionId
				FROM dbo.EsdSourceVersions
				WHERE SourceApplicationId = @CONST_SourceApplicationId_Compass
				GROUP BY SourceVersionId
			)
			INSERT INTO @CompassMeasures
			SELECT
				PM.PlanningMonth
				,@CONST_SourceApplicationId_Compass as SourceApplicationId
				,@CONST_SvdSourceApplicationId_Esd AS SvdSourceApplicationId
				,M.PublishLogId
				,DPH.SnOPDemandProductId
				,M.YearWw
				,M.MeasureQty AS MeasureQty
			FROM dbo.StgCompassMeasure M
			INNER JOIN CTE_EsdSourceVersions ESV ON ESV.SourceVersionId = M.PublishLogId
			INNER JOIN dbo.EsdVersions EV ON EV.EsdVersionId = ESV.EsdVersionId
			INNER JOIN dbo.EsdBaseVersions EBV ON EBV.EsdBaseVersionId = EV.EsdBaseVersionId
			INNER JOIN dbo.PlanningMonths PM ON PM.PlanningMonthId = EBV.PlanningMonthId
			INNER JOIN dbo.SnOPDemandProductHierarchy DPH ON DPH.SnOPDemandProductNm = M.ItemDsc
			WHERE
				M.MeasureNm = 'v_fg_target_woi'
				AND M.MeasureQty <> 0

			--> Validate the Esd Data against the final table
			-- Delete existent rows in compass related to HDMR/NonHDMR
			/*
			DELETE FROM C
			FROM @CompassMeasures C
			INNER JOIN [dbo].[SnOPDemandProductWoiTarget] T
				ON T.PlanningMonth = C.PlanningMonth
				AND T.SnOPDemandProductId = C.SnOPDemandProductId
				AND T.YearWw = C.YearWw
				AND T.SvdSourceApplicationId <> @CONST_SvdSourceApplicationId_Esd
			*/

			------> Merge all the Compass data into the main temp table
			INSERT INTO @SnOPDemandProductWoiTarget
			SELECT
				PlanningMonth
				,SourceApplicationId
				,SvdSourceApplicationId
				,PublishLogId
				,SnOPDemandProductId
				,YearWw
				,MeasureQty
			FROM @CompassMeasures

		END
 
		------> Final Load
		MERGE [dbo].[SnOPDemandProductWoiTarget] AS WOIT --Destination Table
		USING @SnOPDemandProductWoiTarget AS WOIT_S --Source Table
			ON (WOIT.PlanningMonth = WOIT_S.PlanningMonth
			AND WOIT.SourceApplicationId = WOIT_S.SourceApplicationId
			AND WOIT.SvdSourceApplicationId = WOIT_S.SvdSourceApplicationId
			AND WOIT.SourceVersionId = WOIT_S.SourceVersionId
			AND WOIT.SnOPDemandProductId = WOIT_S.SnOPDemandProductId
			AND WOIT.YearWw = WOIT_S.YearWw
		) 
		WHEN MATCHED THEN
		UPDATE SET
			WOIT.Quantity = WOIT_S.Quantity
			, WOIT.Createdon = getdate()
			, WOIT.CreatedBy = original_login()
		WHEN NOT MATCHED BY TARGET THEN 
			INSERT VALUES (
				WOIT_S.PlanningMonth
				,WOIT_S.SourceApplicationId
				,WOIT_S.SvdSourceApplicationId
				,WOIT_S.SourceVersionId
				,WOIT_S.SnOPDemandProductId
				,WOIT_S.YearWw
				,WOIT_S.Quantity
				,getdate()
				,original_login());

		-- Log Handling ********************************************************
		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Info'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @Message
		  , @Status = 'END'
		  , @Exception = NULL
		  , @BatchId = @BatchId;

		RETURN 0;
	END TRY
	BEGIN CATCH
		SELECT
			@ReturnErrorMessage =
			'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
			+ ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
			+ ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
			+ ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Error'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @CurrentAction
		  , @Status = 'ERROR'
		  , @Exception = @ReturnErrorMessage
		  , @BatchId = @BatchId;

		 --re-throw the error
		THROW;

	END CATCH;

	SET NOCOUNT OFF

END
