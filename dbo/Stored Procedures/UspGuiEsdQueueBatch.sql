CREATE PROC [dbo].[UspGuiEsdQueueBatch]
	 @EsdVersionID INT 
	,@TableLoadGroupsList VARCHAR(1000) 
	,@Debug TINYINT = 0
	,@BatchId VARCHAR(100) = NULL

AS
/*********************************************************************************
    Author:         Jeremy Webster

    Purpose:        Receive input from ESD Workbook - Manage ESD Versions UI and schedules ESD Batches to schedule
					ESD Data Extract batches via etl.UspQueueBatchRun procedure

    Called by:      ESD Workbook - Manage ESD Versions UI - C# VSTO Workbook

    Result sets:    None

    Parameters:
					@EsdVersionId int - Esd Version Id of new version or an existing version to be reloaded
					@TableLoadGroupsList - pipe separated list of LoadGroupId's i.e. '1|2|3|4'
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts


    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)

    Exceptions:     None expected

    Date        User				Description
***************************************************************************-
    2020-10-22  Jeremy Webster		Initial Release
    2020-11-10	Ben Sala			Updated logic to use @TableLoadGroupId to queue tables, rather then dynamically trying to build the list.
	2020-12-03	Ben Sala			Updating logic to pull in entire quarter instead of just prior Ww and Prior Month.  Simplied #Batches query 
										and exluded duplicate BatchRun's for Tables that exist across multiple load groups.
	2020-12-04	Jeremy Webster		Added logic to return output parameter for each BatchRunId created for ESD Version - mapped in gui.UIEsdVersionBatchIds
	2020-12-16	Jeremy Webster		Added additional metadata creation logic to track status of data loads
	2021-01-06	Jeremy Webster		Changed name of gui.UIDataLoadEvent to gui.UIDataLoadRequest
	2021-03-23	Ben	Sala			Changed ordering logic for queue order.  Changed actuals to switch back to prior period instead of start of quarter logic.
	2021-05-24	Ben Sala			Adding extra Stich load groups and better handling of table de-deuplication across load groups
	2021-08-24	Ben Sala			Changing PriorMm logic to grab the lesser of PriorMonth or Start of Quarter.
*********************************************************************************
----------------------	TEST HARNESS   --------------------------------------


EXEC dbo.[UspGuiEsdQueueBatch]
    @EsdVersionID = 137
  , @TableLoadGroupsList = '1|2|3|4|5|6|7|8|9|10|11|12|13'
  , @Debug = 1
SELECT * FROM Esd.EsdVersions
SELECT * FROM gui.UIEsdVersionBatchIds
SELECT * FROM gui.DataLoadEvent
*********************************************************************************/


SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************
    DECLARE
        @ReturnErrorMessage VARCHAR(MAX)
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
      , @CurrentAction      VARCHAR(4000)
      , @DT                 VARCHAR(50) = SYSDATETIME();

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

	IF(@BatchId IS NULL) 
		SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

	EXEC dbo.UspAddApplicationLog
		  @LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = @ErrorLoggedBy
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'BEGIN'
		, @Exception = NULL
		, @BatchId = @BatchId;



    -- Parameters and temp tables used by this sp **************************************************

 --declare   @EsdVersionID int = 150
 -- , @TableLoadGroupsList varchar(50) = '1|2|3|4|5|6|7|8|9|10|11|12|13'
 -- , @Debug  int = 1	

	DECLARE @EsdBaseVersionID int
			, @Message			VARCHAR(MAX)
			, @Iterator			INT
			, @MaxIterator		INT
			, @PlanningMonthId		INT
			, @PlanningMonth			INT
			, @PriorMonth			INT
			, @PriorMonthStartWw	INT
			, @TableLoadGroupId	INT
			, @Ordinal INT
			, @QtrstartWW INT
			, @QtrstartMM INT
			, @BatchRunIdOutput INT
			, @DataLoadRequestId INT
			, @TableList VARCHAR(8000);

	IF OBJECT_ID('tempdb..#Batches') IS NOT NULL DROP TABLE #Batches
	CREATE TABLE #Batches
	(
		Iterator INT IDENTITY(1, 1)
		, EsdVersionId INT NULL
		, EsdBaseVersionId INT NULL
		, SourceApplicationName VARCHAR(25) NOT NULL
		, SourceVersionId INT NULL
		, TableList VARCHAR(8000) NOT NULL
		, LoadParameters VARCHAR(100) NOT NULL
		, Ordinal INT NOT NULL
		, TableLoadGroupId INT NOT NULL
	);

	SELECT @DataLoadRequestId = ISNULL(MAX(DataLoadRequestId),0)+1 FROM dbo.GuiUIDataLoadRequest;
    ------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
 --   SELECT @CurrentAction = 'Starting work';

	SELECT @EsdBaseVersionID = EsdBaseVersionId FROM dbo.EsdVersions WHERE EsdVersionId = @EsdVersionID
	SELECT @PlanningMonthId = PlanningMonthId FROM dbo.EsdBaseVersions WHERE EsdBaseVersionId = @EsdBaseVersionId
	SELECT @PlanningMonth = YearMonth FROM dbo.v_ESDCalendar WHERE MonthId = @PlanningMonthId
	SELECT @PriorMonth = YearMonth FROM dbo.v_ESDCalendar WHERE MonthId = @PlanningMonthId - 1
	SELECT @PriorMonthStartWw = MIN(YearWw) FROM dbo.v_ESDCalendar WHERE MonthId = @PlanningMonthId - 1;
	
	SELECT
		@QtrstartWW = MIN(c2.YearWw)
	  , @QtrstartMM = MIN(c2.YearMonth)
	FROM dbo.IntelCalendar       c1 (NOLOCK)
	INNER JOIN dbo.IntelCalendar c2 (NOLOCK)
		ON c2.IntelYear = c1.IntelYear
		   AND c2.IntelQuarter = c1.IntelQuarter
	WHERE
		c1.MonthId = @PlanningMonthId;
		


	WITH TableList AS 
		(
		SELECT
			SA.SourceApplicationName
		  , ESV.SourceVersionId
		  , RT.LoadParameters
		  , RT.TableId
		  , RT.TableName
		  , LG.TableLoadGroupId
		  , Ordinal = 
				CASE 
					WHEN map.TableLoadGroupId IN (9,10,11) THEN 101 --'SvD Stitch'
					WHEN map.TableLoadGroupId = 7 THEN 102 --'Total SvD Stitch'
					WHEN SA.SourceApplicationName IN ('Denodo', 'VIPRE', 'RVM') THEN 1
					WHEN map.TableLoadGroupId = 4 THEN 2 --Mappings
					WHEN map.TableLoadGroupId = 8 AND SA.SourceApplicationName IN ('IsMps', 'FabMps') THEN 3
					WHEN map.TableLoadGroupId = 8 AND SA.SourceApplicationName IN ('OneMps') THEN 4
					WHEN map.TableLoadGroupId IN (1,6) THEN 6 --'Actuals', 'Forecast'
					WHEN map.TableLoadGroupId = 5 AND SA.SourceApplicationName IN ('IsMps', 'FabMps') THEN 7
					WHEN map.TableLoadGroupId = 5 AND SA.SourceApplicationName IN ('OneMps') THEN 8
					ELSE 100 --Everything else that isn't defined, do it just before SvD Stich
				END
				
		FROM   [dbo].[EtlTables]         RT
		INNER JOIN [dbo].[EtlSourceApplications]   SA
			ON RT.SourceApplicationId = SA.SourceApplicationId
		INNER JOIN [dbo].[EtlTableLoadGroupMap] map
			ON map.TableId = RT.TableId
		INNER JOIN  [dbo].[EtlTableLoadGroups]  LG
			ON LG.TableLoadGroupId = map.TableLoadGroupId
			   AND LG.GroupType = 'ESD'
		OUTER APPLY (SELECT sv.SourceVersionId FROM dbo.EsdSourceVersions sv WHERE sv.SourceApplicationId = rt.SourceApplicationId AND sv.EsdVersionId = @EsdVersionID) ESV
		WHERE
			EXISTS (SELECT 1 FROM STRING_SPLIT(@TableLoadGroupsList, '|') ss WHERE map.TableLoadGroupId = ss.value)
			AND RT.Active = 1
			AND RT.TableName NOT IN ('dbo.ActualFgMovements','dbo.ActualSupply')
			AND LG.TableLoadGroupId NOT in (1, 2,12)
		--ORDER BY Ordinal
		)
	, TableListDeDupe AS 
		(
		SELECT 
			   b.SourceApplicationName
			 , b.SourceVersionId
			 , b.LoadParameters
			 , b.TableName
			 , b.Ordinal
			 , b.TableLoadGroupId
			 , b.TableId
			 , RowNum = ROW_NUMBER() OVER (PARTITION BY b.TableId, ISNULL(b.SourceVersionId,0) ORDER BY b.Ordinal, TableLoadGroupId)
		FROM TableList b
		)
	INSERT INTO #Batches
	(
	    EsdVersionId
	  , EsdBaseVersionId
	  , SourceApplicationName
	  , SourceVersionId
	  , LoadParameters
	  , Ordinal
	  , TableLoadGroupId
	  , TableList
	)
	SELECT 
		@EsdVersionID     AS EsdVersionId
		, @EsdBaseVersionID AS EsdBaseVersionId
		, tld.SourceApplicationName
        , tld.SourceVersionId
        , tld.LoadParameters
		, tld.Ordinal
		, TableLoadGroupID = MIN(tld.TableLoadGroupId)
        , TableList = 
			(SELECT 
				STUFF(
					CAST((
						SELECT DISTINCT '|' + tld2.TableName
						FROM TableListDeDupe tld2 
						WHERE tld.SourceApplicationName = tld2.SourceApplicationName AND ISNULL(tld.SourceVersionId,0) = ISNULL(tld2.SourceVersionId,0)
							AND tld2.Ordinal = tld.Ordinal
							AND tld2.LoadParameters = tld.LoadParameters
							AND tld2.RowNum = 1
						ORDER BY 1
						FOR XML PATH('')
						) AS VARCHAR(MAX))
				, 1,1, ''
				))
	FROM TableListDeDupe tld
	WHERE 
		tld.RowNum = 1
	GROUP BY tld.SourceApplicationName
           , tld.SourceVersionId
           , tld.LoadParameters
		   , tld.Ordinal
	ORDER BY 
		tld.Ordinal
		, tld.SourceApplicationName

	
	
	SELECT @MaxIterator = MAX(Iterator) FROM #Batches;
	SET @Iterator = 1;

	IF(@Debug >= 1)
		SELECT * FROM #Batches;


	DECLARE
		  @SrcAppName    VARCHAR(1000)
		, @SrcVersionId  VARCHAR(1000)
		, @EsdVerId      VARCHAR(1000)
		, @EsdBaseVerId  VARCHAR(1000)
		, @LoadParams    VARCHAR(100)
		, @WorkingYearWw VARCHAR(1000)
		, @WorkingYearMm VARCHAR(1000)
		, @GlobalConfig  VARCHAR(1000)
		, @Datetime      VARCHAR(1000)
		, @CompassPublishLogId  VARCHAR(1000)
		, @Map           VARCHAR(1000);


	WHILE @Iterator <= @MaxIterator 
	BEGIN 
		SELECT 
			@SrcAppName = CAST(b.SourceApplicationName AS VARCHAR(1000)) 
			, @TableLoadGroupId = b.TableLoadGroupId
			, @LoadParams = b.LoadParameters
			, @TableList = b.TableList
		FROM #Batches b
		WHERE 
			b.Iterator = @Iterator;

		IF(@LoadParams LIKE '%SourceVersionId%')
			BEGIN
				SELECT @SrcVersionId =	CAST(SourceVersionId  AS VARCHAR(1000))	from #Batches WHERE Iterator = @Iterator
			END
		ELSE
			BEGIN
				SET @SrcVersionId =	NULL
			END

		IF(@LoadParams LIKE '%EsdVersionId%')
			BEGIN
				SELECT @EsdVerId = CAST(EsdVersionId	 AS VARCHAR(1000))	from #Batches WHERE Iterator = @Iterator
			END
		ELSE
			BEGIN
				SET @EsdVerId = NULL
			END

		IF(@LoadParams LIKE '%EsdBaseVersionId%')
			BEGIN
				SELECT @EsdBaseVerId =	CAST(EsdBaseVersionId AS VARCHAR(1000))	from #Batches WHERE Iterator = @Iterator
			END
		ELSE
			BEGIN
				SET @EsdBaseVerId = NULL
			END

		IF(@LoadParams LIKE '%YearWw%')
			BEGIN
				SELECT @WorkingYearWw = @PriorMonthStartWw --@QtrstartWW
			END
		ELSE
			BEGIN
				SET @WorkingYearWw = NULL
			END

		IF(@LoadParams LIKE '%YearMm%')
			BEGIN
				SELECT @WorkingYearMm = --@PriorMonth --@QtrstartMM
					CASE WHEN @PriorMonth < @QtrstartMM THEN @PriorMonth ELSE @QtrstartMM END
			END
		ELSE
			BEGIN
				SET @WorkingYearMm = NULL
			END

		IF (@LoadParams LIKE '%GlobalConfig%')
			BEGIN
				SET @GlobalConfig = 1
			END
		ELSE
			BEGIN
				SET @GlobalConfig = NULL
			END

		IF (@LoadParams LIKE '%Datetime%')
			BEGIN
				SET @Datetime = getdate()
			END
		ELSE
			BEGIN
				SET @Datetime = NULL
			END

					IF (@LoadParams LIKE '%CompassPublishLogId%')
			BEGIN
				SET @CompassPublishLogId = (SELECT CAST(SourceVersionId AS VARCHAR(1000)) FROM dbo.EsdSourceVersions WHERE EsdVersionId = @EsdVersionID AND SourceApplicationId = 12 )
			END
		ELSE
			BEGIN
				SET @CompassPublishLogId = NULL
			END

		

		If (@LoadParams LIKE '%Map%')
			BEGIN
				SET @Map = 1
			END
		ELSE
			BEGIN
				SET @Map = NULL
			END


		IF (@Debug >= 1)
		BEGIN
			SELECT @SrcAppName as SrcAppName,@SrcVersionId as SrcVersionId, @EsdVerId as EsdVersionId, @EsdBaseVerId as ESDBaseVersionId, @TableLoadGroupId as TableLoadGroupId,@Ordinal AS Ordinal, @WorkingYearMm as YearMm, @WorkingYearWw as YearWw,@TableList AS TableList
			--RAISERROR('%s - %s', 0, 1, @DT, @CurrentAction) WITH NOWAIT;
		END;

		--Queue Batch Run
		EXEC [dbo].[UspEtlQueueBatchRun]
			@Debug=@Debug
			,@BatchRunId = @BatchRunIdOutput OUTPUT
			,@SourceApplicationName=@SrcAppName
			,@SourceVersionId = @SrcVersionId
			,@EsdVersionId=@EsdVerId
			,@EsdBaseVersionId=@EsdBaseVerId
			,@TableList = @TableList
			,@YearMm=@WorkingYearMm
			,@YearWw=@WorkingYearWw
			,@GlobalConfig = @GlobalConfig
			,@CompassPublishLogId = @CompassPublishLogId
			,@Datetime = @Datetime
			,@Map = @Map;
		IF(@Debug >= 1)
			SELECT @EsdVersionID As EsdVersionForMapping,@BatchRunIdOutput AS BatchRunIdForMapping;




		INSERT INTO [dbo].[GuiUIDataLoadRequest] ([DataLoadRequestId],[EsdVersionId],[TableLoadGroupId],[BatchRunId])
		SELECT @DataLoadRequestId, @EsdVersionID, @TableLoadGroupId,@BatchRunIdOutput



		SET @Iterator = @Iterator +1;
	END; 



	DROP TABLE #Batches;


    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Done';
    IF (@Debug >= 1)
    BEGIN
        SELECT @DT = SYSDATETIME();
        RAISERROR('%s - %s', 0, 1, @DT, @CurrentAction) WITH NOWAIT;
    END;

	EXEC dbo.UspAddApplicationLog
		  @LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = @ErrorLoggedBy
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'END'
		, @Exception = NULL
		, @BatchId = @BatchId;


    RETURN 0;
END TRY
BEGIN CATCH
	SELECT
		@ReturnErrorMessage = 
			'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) 
			+ ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50)) 	
			+ ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) 	
			+ ' Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>')
			+ ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') 
			+ ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


	EXEC dbo.UspAddApplicationLog
		  @LogSource = 'Database'
		, @LogType = 'Error'
		, @Category = @ErrorLoggedBy
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'ERROR'
		, @Exception = @ReturnErrorMessage
		, @BatchId = @BatchId;

    -- re-throw the error
    THROW;

END CATCH;