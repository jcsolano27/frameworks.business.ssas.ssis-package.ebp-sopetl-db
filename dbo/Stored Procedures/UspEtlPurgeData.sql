CREATE PROC [dbo].[UspEtlPurgeData]
      @Debug TINYINT = 0
	, @BatchId VARCHAR(100) = NULL
	, @SourceApplicationName VARCHAR(25)
	, @TableName VARCHAR(256)
	, @BatchRunId INT
	, @ParameterList VARCHAR(1000)
	, @StagingTableName VARCHAR(8000) = NULL
	, @PurgeCustomMessage2 VARCHAR(8000) = NULL
AS
/*********************************************************************************
    Author:         Ben Sala
     
    Purpose:        Purges existing records to prepare for incoming data load. 

    Called by:      SSIS - All child ETL packagess
					
         
    Result sets:    None
     
    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 1	= @Debug >= 1 will not execute the purge.
     
    Exceptions:     None expected
     
    Date        User		    Description
***************************************************************************-
    2020-09-08  Ben Sala		Initial Release
    2020-10-05	Ben Sala		Adding staging table logic 
    2020-12-07	Ben Sala		Adding call to TableLoadStatus to show time the purge took to run. 
*********************************************************************************


EXEC dbo.UspEtlPurgeData
    @Debug = 1                  -- tinyint
  --, @BatchId = ''               -- varchar(100)
  , @SourceApplicationName = 'FabMps' -- varchar(25)
  , @TableName = 'esd.EsdDataAdjTotalTargetWoi'             -- varchar(255)
  , @LoadParameters = 'EsdVersionId|SourceVersionId'              -- varchar(100)
  , @BatchRunId = 0             -- int
  , @ParameterList = 'EsdVersionId=0|SourceVersionId=0'         -- varchar(1000)



****************************************************************************/


SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************
    DECLARE
        @ReturnErrorMessage VARCHAR(MAX)
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
      , @CurrentAction      VARCHAR(4000)
      , @DT                 VARCHAR(50) = SYSDATETIME()
	  , @Message			VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

	IF(@BatchId IS NULL) 
		SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();
	
	SELECT @Message = 'Purging SourceApplicationName: ' + @SourceApplicationName + ' TableName: ' + @TableName + ' ParameterList: ' + @ParameterList;

	EXEC dbo.UspAddApplicationLog
		  @LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @Message
		, @Status = 'BEGIN'
		, @Exception = NULL
		, @BatchId = @BatchId;



    -- Parameters and temp tables used by this sp **************************************************
	DECLARE @RowCount INT
		, @RowCountOut1 INT
		, @RowCountOut2 INT
		, @RowCountOut3 INT
		, @SourceVersionId INT
		, @SnapshotId INT 
		, @YearWw INT 
		, @YearMm INT 
		, @EsdVersionId INT 
		, @EsdBaseVersionId INT 
		, @Map INT
		, @DeltaDatetime VARCHAR(100)
		, @CompassPublishLogId INT
        , @GlobalConfig VARCHAR(8000)
		, @SQLCMD NVARCHAR(MAX)
		, @SourceApplicationId INT
		, @LoadParametersDefined VARCHAR(100)
		, @DefinedStagingTableName VARCHAR(8000)
		, @WorkingTableName VARCHAR(500)
		, @WorkingID INT
		;
	
	DECLARE @Params TABLE (ParameterName VARCHAR(900) NOT NULL PRIMARY KEY CLUSTERED, ParameterValue VARCHAR(1000) NOT NULL);

	DECLARE @LoadParametersValidation TABLE (ParameterName VARCHAR(900) NOT NULL PRIMARY KEY CLUSTERED);

	DECLARE @StagingTables TABLE (ID INT IDENTITY(1,1) NOT NULL, StagingTableName VARCHAR(500) NOT NULL PRIMARY KEY CLUSTERED, Status INT NOT NULL);
    ------------------------------------------------------------------------------------------------
    -- Validation ********************************************************************************
    SELECT @CurrentAction = 'Splitting parameters and validation';

	INSERT INTO @Params (ParameterName, ParameterValue)
	SELECT 
		ParameterName = SUBSTRING(p.value,0,CHARINDEX('=', p.value))
		, ParameterValue = SUBSTRING(p.value,CHARINDEX('=', p.value) + 1, 1000)
	FROM STRING_SPLIT(@ParameterList, '|') p;
		
	SELECT @SourceVersionId = ParameterValue FROM @Params WHERE ParameterName = 'SourceVersionId';
	SELECT @SnapshotId = ParameterValue FROM @Params WHERE ParameterName = 'SnapshotId';
	SELECT @EsdVersionId = ParameterValue FROM @Params WHERE ParameterName = 'EsdVersionId';
	SELECT @EsdBaseVersionId = ParameterValue FROM @Params WHERE ParameterName = 'EsdBaseVersionId';
	SELECT @YearWw = ParameterValue FROM @Params WHERE ParameterName = 'YearWw';
	SELECT @YearMm = ParameterValue FROM @Params WHERE ParameterName = 'YearMm'
	SELECT @Map = ParameterValue FROM @Params WHERE ParameterName = 'Map';
	SELECT @DeltaDatetime = ParameterValue FROM @Params WHERE ParameterName = 'Datetime';
	SELECT @CompassPublishLogId = ParameterValue FROM @Params WHERE ParameterName = 'CompassPublishLogId';

	SELECT @SourceApplicationId = sa.SourceApplicationId
	FROM dbo.EtlSourceApplications sa
	WHERE 
		sa.SourceApplicationName = @SourceApplicationName;

	SELECT 
		  @SQLCMD = rt.PurgeScript
		  , @LoadParametersDefined = rt.LoadParameters
		  , @DefinedStagingTableName = rt.StagingTables
	FROM dbo.EtlTables rt
	WHERE 
		rt.TableName = @TableName
		AND rt.SourceApplicationId = @SourceApplicationId;

	IF(@SQLCMD IS NULL)
		RAISERROR('Unable to get purge script for SourceApplicationId: %d TableName: %s',16,1,@SourceApplicationId, @TableName);

	
	INSERT INTO @LoadParametersValidation (ParameterName)
	SELECT value
	FROM STRING_SPLIT(@LoadParametersDefined,'|');

	INSERT INTO @StagingTables (StagingTableName, Status)
	SELECT value, 0
	FROM STRING_SPLIT(@StagingTableName,'|')
	ORDER BY value;
	

	IF EXISTS 
		(
		SELECT 1 
		FROM STRING_SPLIT(@DefinedStagingTableName,'|') Expected
		FULL OUTER JOIN @StagingTables Actual
			ON Actual.StagingTableName = Expected.value
		WHERE Expected.value IS NULL OR Actual.StagingTableName IS NULL			
		)
		RAISERROR('Passed in @StagingTableName: "%s" does not match dbo.EtlTables defined StagingTableName: "%s"',16,1,@StagingTableName, @DefinedStagingTableName);


	IF EXISTS (
		SELECT 1
		FROM @LoadParametersValidation v
		LEFT JOIN @Params p
			ON p.ParameterName = v.ParameterName
		WHERE p.ParameterValue IS NULL
		)
	BEGIN
		IF(@Debug >= 1)
			SELECT v.ParameterName
                 , p.ParameterValue
			FROM @LoadParametersValidation v
			LEFT JOIN @Params p
				ON p.ParameterName = v.ParameterName
			WHERE p.ParameterValue IS NULL;

		RAISERROR('Required parameter for table %s is missing',16,1,@TableName)

	END

	IF EXISTS (SELECT 1 FROM @Params WHERE ISNULL(ParameterName,'') NOT IN ('SnapshotId', 'SourceVersionId', 'ESDVersionId', 'ESDBaseVersionId','YearWw', 'YearMm', 'Map','Datetime','CompassPublishLogId','GlobalConfig'))
	BEGIN
		IF(@Debug >= 1)
			SELECT 
				  ParameterName 
				, ParameterValue 
			FROM @Params 
			WHERE ISNULL(ParameterName,'') NOT IN ('SnapshotId', 'SourceVersionId', 'ESDVersionId', 'ESDBaseVersionId','YearWw', 'YearMm', 'Map','Datetime', 'CompassPublishLogId','GlobalConfig');

		RAISERROR('Invalid parameter names passed in or parsing error occurred',16,1);
	END

	SELECT @CurrentAction = 'Executing Purge';

	
	IF(@Debug >= 1)
	BEGIN
		SELECT 
			SQLCMD = @SQLCMD
			, SourceApplicationName = @SourceApplicationName
			, SourceVersionId = @SourceVersionId
			, SnapshotId = @SnapshotId
			, EsdVersionId = @EsdVersionId
			, EsdBaseVersionId = @EsdBaseVersionId
			, YearWw = @YearWw
			, YearMm = @YearMm
            , Map = @Map
            , GlobalConfig = @GlobalConfig
			, DeltaDatetime = @DeltaDatetime
			, CompassPublishLogId = @CompassPublishLogId

		-- if @Debug level at 2 do not execute purge script.
		IF(@Debug >= 2)
			RETURN 1;
	END;

	
	-- Starting work -------------------------------------------------------------------------------------
	
	IF(@StagingTableName IS NULL)
	BEGIN
		SELECT @CurrentAction = 'Setting processing started for Primary table';
		SELECT @RowCount = ISNULL(@RowCountOut1, @RowCount);

		EXEC dbo.UspEtlMergeTableLoadStatus
			@Debug = @Debug
			, @BatchRunId = @BatchRunId
			, @SourceApplicationName = @SourceApplicationName
			, @TableName = @TableName
			, @BatchId = @BatchId
			, @ParameterList = @ParameterList
			, @StagingTableName = @WorkingTableName
			, @ProcessingStarted = 1;
	END
	-- Need to log the actual time processing started, not after the purge runs like we do now. 
	-- Loops through all staging tables.
	SELECT @CurrentAction = 'Setting processing started for staging table(s)';
	WHILE EXISTS (SELECT 1 FROM @StagingTables WHERE Status = 0)
	BEGIN
		SELECT TOP (1)
			@WorkingTableName = StagingTableName
			, @WorkingID = ID
		FROM @StagingTables
		WHERE Status = 0
		ORDER BY StagingTableName;

		EXEC dbo.UspEtlMergeTableLoadStatus
			@Debug = @Debug
			, @BatchRunId = @BatchRunId
			, @SourceApplicationName = @SourceApplicationName
			, @TableName = @TableName
			, @BatchId = @BatchId
			, @ParameterList = @ParameterList
			, @StagingTableName = @WorkingTableName
			, @ProcessingStarted = 1;

		SELECT @Message = 'Started processing table: ' + ISNULL(@StagingTableName, @TableName);

		UPDATE @StagingTables SET STATUS = 1 WHERE StagingTableName = @WorkingTableName;
	END;


	EXEC sys.sp_executesql 
		  @stmt = @SQLCMD
		, @Params = N'@RowCountOut1 INT OUTPUT, @RowCountOut2 INT OUTPUT, @RowCountOut3 INT OUTPUT, @SourceApplicationName VARCHAR(25), @SourceVersionId INT, @SnapshotId INT, @EsdVersionId INT, @EsdBaseVersionId INT, @YearWw INT, @YearMm INT, @Map INT,@DeltaDatetime VARCHAR(100), @CompassPublishLogId INT,@GlobalConfig VARCHAR(8000)'
		, @RowCountOut1 = @RowCountOut1 OUTPUT
		, @RowCountOut2 = @RowCountOut2 OUTPUT
		, @RowCountOut3 = @RowCountOut3 OUTPUT
		, @SourceApplicationName = @SourceApplicationName
		, @SourceVersionId = @SourceVersionId
		, @SnapshotId = @SnapshotId
		, @EsdVersionId = @EsdVersionId
		, @EsdBaseVersionId = @EsdBaseVersionId
		, @YearWw = @YearWw
		, @YearMm = @YearMm
		, @Map = @Map
		, @DeltaDatetime = @DeltaDatetime
		, @CompassPublishLogId = @CompassPublishLogId
        , @GlobalConfig = @GlobalConfig
		;
	SELECT @RowCount = @@ROWCOUNT;	

	
	
	
	SELECT @CurrentAction = 'Updating table load status with purge numbers.';

	IF(@StagingTableName IS NULL)
	BEGIN
		SELECT @CurrentAction = 'Setting purge row count for primary table';
		SELECT @RowCount = ISNULL(@RowCountOut1, @RowCount);

		EXEC dbo.UspEtlMergeTableLoadStatus
			@Debug = @Debug
			, @BatchRunId = @BatchRunId
			, @SourceApplicationName = @SourceApplicationName
			, @TableName = @TableName
			, @RowsPurged = @RowCount
			, @BatchId = @BatchId
			, @ParameterList = @ParameterList
			, @StagingTableName = @WorkingTableName
			, @ProcessingStarted = 0;
	END

	-- Only call this if it's not being staged.  Table status will be handled in the Process SP when dealing with staged data.

	-- Loops through all staging tables.
	WHILE EXISTS (SELECT 1 FROM @StagingTables WHERE STATUS = 1)
	BEGIN
		SELECT TOP (1)
			@WorkingTableName = StagingTableName
            , @WorkingID = ID
		FROM @StagingTables
		WHERE Status = 1
		ORDER BY StagingTableName;

		SELECT @RowCount = 
			CASE @WorkingID
				WHEN 1 THEN COALESCE(@RowCountOut1, @RowCount, -11)
				WHEN 2 THEN COALESCE(@RowCountOut2, -11)
				WHEN 3 THEN COALESCE(@RowCountOut3, -11)
				ELSE -12
			END;

		EXEC dbo.UspEtlMergeTableLoadStatus
			  @Debug = @Debug
			, @BatchRunId = @BatchRunId
			, @SourceApplicationName = @SourceApplicationName
			, @TableName = @TableName
			, @RowsPurged = @RowCount
			, @BatchId = @BatchId
			, @ParameterList = @ParameterList
			, @StagingTableName = @WorkingTableName
			, @ProcessingStarted = 0;


		SELECT @Message = 'Purged ' + CAST(@RowCount AS VARCHAR(50)) + ' Rows from: ' + ISNULL(@StagingTableName, @TableName);

		UPDATE @StagingTables SET STATUS = 2 WHERE StagingTableName = @WorkingTableName;
	END;
	IF(@Debug >= 1)
		SELECT [RowCount] = @RowCount
			, RowCountOut1 = @RowCountOut1
			, RowCountOut2 = @RowCountOut2
			, RowCountOut3 = @RowCountOut3

	IF(@PurgeCustomMessage2 IS NOT NULL AND @RowCountOut2 > 0)
	BEGIN
		SELECT @PurgeCustomMessage2 = @PurgeCustomMessage2 + ' - RowCount: ' + CAST(@RowCountOut2 AS VARCHAR(50))
		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Warning'
			, @Category = 'Etl'
			, @SubCategory = @ErrorLoggedBy
			, @Message = @PurgeCustomMessage2
			, @Status = 'END'
			, @Exception = NULL
			, @BatchId = @BatchId;
	END

	EXEC dbo.UspAddApplicationLog
		@LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @Message
		, @Status = 'END'
		, @Exception = NULL
		, @BatchId = @BatchId;



    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Done';
    IF (@Debug >= 1)
    BEGIN
        SELECT @DT = SYSDATETIME();
        RAISERROR('%s - %s', 0, 1, @DT, @CurrentAction) WITH NOWAIT;
    END;



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
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'ERROR'
		, @Exception = @ReturnErrorMessage
		, @BatchId = @BatchId;

    -- re-throw the error
    THROW;

END CATCH;


