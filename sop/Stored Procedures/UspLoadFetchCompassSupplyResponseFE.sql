
CREATE   PROCEDURE [sop].[UspLoadFetchCompassSupplyResponseFE]
(
	@RunId INT,
	@Debug BIT = 0
)

AS

/********************************************************************************
Purpose: Fetch data from Compass Source through Linked Server to load sop.StgMfgSupplyResponseFe Stage table
Main Tables:

Called by: Etl/Agent Job

Result sets: None

Parameters:
	@RunId:
		Id needed to filter a specific Compass version. Will work like EsdVersionId
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
	- (Rachel) There currently exists a dependency on an artifact that only exists in Compass Replication.
		Rachel to follow up w. Catie 7/6 AM to retrieve definition for view and develop equivalent to execute in this block of logic. 

 
	Date		User		Description
*********************************************************************************-
	2023-07-10	hmanentx	Initial Release

*********************************************************************************/

BEGIN

	SET NOCOUNT ON

	BEGIN TRY

		DECLARE @EmailMessage							VARCHAR(1000) = 'LoadProduct Successful'
		DECLARE @Prog									VARCHAR(255)
		
		DECLARE @ReturnErrorMessage						VARCHAR(MAX)
		DECLARE @ErrorLoggedBy							VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		DECLARE @CurrentAction							VARCHAR(4000)
		DECLARE @DT										VARCHAR(50)  = SYSDATETIME()
		DECLARE @Message								VARCHAR(MAX)
		DECLARE @BatchId								VARCHAR(512)

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

		--------------------------------------------------------------------------------
		-- Parameters Declaration/Initialization
		--------------------------------------------------------------------------------
		DECLARE @CONST_SourceSystemId_Compass	INT = (SELECT [sop].[CONST_SourceSystemId_Compass]())
		DECLARE @PlanningMonth					INT = (SELECT PlanningMonthEndNbr FROM sop.fnGetReportPlanningMonthRange())
		DECLARE @ItemClassId_Sort				INT = (SELECT DISTINCT ItemClassId FROM COMPASSPROD.Compass.dbo.RefItemClasses WHERE ItemClassName = 'SORT')

		--------------------------------------------------------------------------------
		-- Loading Compass Wafer Data
		--------------------------------------------------------------------------------
		DROP TABLE IF EXISTS #CompassWaferOuts
		SELECT DISTINCT
			@PlanningMonth AS PlanningMonth
			,I.ItemClassId
			,I.ItemDescription
			,DBLW.InItemId as WaferInItemId
			,O.RunId
			,O.ScenarioId
			,O.ProfileId
			,O.BomHeaderId
			,O.IntraPlantRouteId
			,O.LocationId
			,O.ItemGroupId
			,O.ItemId
			,O.BucketTypeId
			,O.BucketId
			,O.Quantity
			,O.GdpwBucketTypeId
			,O.GdpwBucketId
			,O.QuantityInUnits
		INTO #CompassWaferOuts
		FROM COMPASSPROD.Compass.dbo.OutputMfgOuts O
		INNER JOIN COMPASSPROD.Compass.dbo.RefItems i ON o.ItemId = i.ItemId
		INNER JOIN COMPASSPROD.Compass.dbo.DataSolveRun D ON D.RunId = O.RunId
		INNER JOIN COMPASSPROD.Compass.dbo.DataBomLinks DBL
								ON DBL.ScenarioId = D.ScenarioId
								AND DBL.BomHeaderId = O.BomHeaderId
								AND DBL.OutItemId = O.ItemId
		INNER JOIN COMPASSPROD.Compass.dbo.DataBomLinks DBLW ON DBLW.ScenarioId = D.ScenarioId AND DBLW.OutItemId = DBL.InItemId
		WHERE
			O.RunId = @RunId
			AND i.ItemClassId = @ItemClassId_Sort

		IF @Debug = 1 BEGIN
			SELECT @RunId AS RunId
			SELECT
				I.ItemClassId
				,SUM(O.QuantityInUnits) AS SumOfQuantityInUnits
				,COUNT(1) AS RowQty
			FROM #CompassWaferOuts
		END

		--------------------------------------------------------------------------------
		-- Summarizing and bringing the domain data for the query
		--------------------------------------------------------------------------------
		DROP TABLE IF EXISTS #CompassSummarizedWaferOuts
		SELECT
			O.PlanningMonth
			,@CONST_SourceSystemId_Compass AS SourceSystemId
			,RunId AS PlanVersionId
			,NULL AS Process
			,WI.ItemName AS WaferItemName
			,WI.ItemDescription AS WaferItemDescription
			,SI.ItemName AS SortItemName
			,SI.ItemDescription AS SortItemDescription
			,RL.LocationName
			,RIC.YearWw AS IntelYearWw
			,RIC.IntelYear * 100 + RIC.IntelQuarter AS IntelYearQuarter
			,SUM(QuantityInUnits) AS SortOutQty
			,SUM(Quantity) AS WaferOutQty
		INTO #CompassSummarizedWaferOuts
		FROM #CompassWaferOuts O
		INNER JOIN COMPASSPROD.Compass.dbo.RefItems SI ON O.ItemId = SI.ItemId
		INNER JOIN COMPASSPROD.Compass.dbo.RefItems WI ON O.WaferInItemId = WI.ItemId
		INNER JOIN COMPASSPROD.Compass.dbo.RefLocations RL ON RL.LocationId = O.LocationId
		INNER JOIN COMPASSPROD.Compass.dbo.RefIntelCalendar RIC ON RIC.WwId = O.BucketId
		GROUP BY
			O.PlanningMonth
			,ScenarioId
			,RunId
			,WaferInItemId
			,WI.ItemName
			,WI.ItemDescription
			,O.ItemId
			,SI.ItemName
			,SI.ItemDescription
			,RL.LocationName
			,RIC.YearWw
			,RIC.IntelYear
			,RIC.IntelQuarter

		IF @Debug = 1 BEGIN
			SELECT
				PlanVersionId
				,PlanningMonth
				,SUM(SortOutQty) AS SumOfSortOutQty
				,SUM(WaferOutQty) AS SumOfWaferOutQty
				,COUNT(1) AS RowQty
			FROM #CompassSummarizedWaferOuts
			GROUP BY
				PlanVersionId
				,PlanningMonth
		END

		--------------------------------------------------------------------------------
		-- Inserting final data into the sop Stage
		--------------------------------------------------------------------------------
		INSERT INTO sop.StgMfgSupplyResponseFe
		(
			PlanningMonth
			,SourceSystemId
			,SourceVersionId
			,Process
			,WaferItemName
			,WaferItemDescription
			,SortItemName
			,SortItemDescription
			,LocationName
			,IntelYearWw
			,IntelYearQuarter
			,SortOutQty
			,WaferOutQty
		)
		SELECT
			PlanningMonth
			,SourceSystemId
			,PlanVersionId
			,Process
			,WaferItemName
			,WaferItemDescription
			,SortItemName
			,SortItemDescription
			,LocationName
			,IntelYearWw
			,IntelYearQuarter
			,SortOutQty
			,WaferOutQty
		FROM #CompassSummarizedWaferOuts

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
		EXEC [sop].[UspMPSReconSendEmail] @EmailBody = @EmailMessage,@EmailSubject='[sop].UspLoadFetchCompassSupplyResponseFE Successful'

	END TRY

	BEGIN CATCH

		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='LoadSupplyResponseFromCompass failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC sop.UspMPSReconSendEmail @EmailBody = @EmailMessage,@EmailSubject='[sop].UspLoadFetchCompassSupplyResponseFE Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		
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
