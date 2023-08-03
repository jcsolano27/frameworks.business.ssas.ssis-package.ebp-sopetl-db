CREATE PROC [sop].[UspQueueBatchRun]
    @Debug TINYINT = 0,
    @BatchRunID INT = NULL OUTPUT, -- returns BatchRunId created  
    @BatchId VARCHAR(100) = NULL,
    @PackageSystemName VARCHAR(100),
    @SourceVersionId INT = NULL,
    @TableList VARCHAR(MAX) = NULL,
    @TestFlag TINYINT = 0,
    @Map INT = NULL,
    @TableLoadGroupId INT = NULL,
    @GlobalConfig INT = NULL,
    @Datetime VARCHAR(100) = NULL
AS

----/*********************************************************************************  

---- Purpose: Creates a BatchRun record to be processed on the next run.  
---- Parameters:  
----  @Debug:  
----            1 - Will output some basic info with timestamps  
----            2 - Will output everything from 1, as well as rowcounts  

---- Return Codes:    
----   0   = Success  
----            < 0 = Error  
----            > 0 (No warnings for this SP, should never get a returncode > 0)  

----    Date        User            Description  
----***************************************************************************-  
----    2023-06-16 atairumx        Initial Release  

----*********************************************************************************/  

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************  
    DECLARE @ReturnErrorMessage VARCHAR(MAX),
            @ErrorLoggedBy VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),
            @CurrentAction VARCHAR(4000),
            @DT VARCHAR(50) = SYSDATETIME(),
            @Message VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

    IF (@BatchId IS NULL)
        SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Info',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @Message,
                                  @Status = 'BEGIN',
                                  @Exception = NULL,
                                  @BatchId = @BatchId;



    -- Parameters and temp tables used by this sp **************************************************  
    DECLARE @LoadParameters VARCHAR(100),
            @ParameterList VARCHAR(1000),
            @PackageSystemId INT;

    DECLARE @Params TABLE
    (
        ParameterName VARCHAR(1000) NOT NULL,
        ParameterValue VARCHAR(1000) NOT NULL
    );

    DECLARE @LoadParametersValidation TABLE
    (
        ParameterName VARCHAR(1000) NOT NULL
    );

    ------------------------------------------------------------------------------------------------  
    -- Perform work ********************************************************************************  
    SELECT @CurrentAction = 'Validation';

    SELECT @PackageSystemId = sa.PackageSystemId
    FROM sop.PackageSystem sa
    WHERE sa.PackageSystemNm = @PackageSystemName;

    IF (@PackageSystemId IS NULL AND @PackageSystemId <> -1)
        RAISERROR('Invalid PackageSystemName: %s', 16, 1, @PackageSystemName);

    SELECT @LoadParameters
        = CASE
			WHEN @SourceVersionId IS NOT NULL THEN
			'|SourceVersionId'
			ELSE
			''
		END + CASE
			WHEN @GlobalConfig IS NOT NULL THEN
			'|GlobalConfig'
			ELSE
			''
		END + CASE
			WHEN @Datetime IS NOT NULL THEN
			'|Datetime'
			ELSE
			''
		END;


    SELECT @ParameterList
        = ISNULL('|SourceVersionId=' + CAST(@SourceVersionId AS VARCHAR(1000)), '')
          + ISNULL('|GlobalConfig=' + CAST(@GlobalConfig AS VARCHAR(1000)), '')
          + ISNULL('|Datetime=' + CAST(@Datetime AS VARCHAR(1000)), '');

    SELECT @LoadParameters = STUFF(@LoadParameters, 1, 1, ''); --Remove the first '|'  
    SELECT @ParameterList = STUFF(@ParameterList, 1, 1, ''); --Remove the first '|'  

    IF (@Debug >= 1)
        SELECT LoadParameters = @LoadParameters,
               ParameterList = @ParameterList,
               PackageSystemId = @PackageSystemId;

    IF (ISNULL(LEN(@LoadParameters), 0) = 0)
        RAISERROR('Could not build LoadParameters based on parameters passed in', 16, 1);

    IF (ISNULL(LEN(@ParameterList), 0) = 0)
        RAISERROR('Could not build ParameterList based on parameters passed in', 16, 1);

    IF (@TableLoadGroupId IS NOT NULL)
    BEGIN
        SELECT @CurrentAction = 'Dynamically building table list based on passed in @TableLoadGroupId';

        SELECT @TableList = STUFF(CAST(
        (
            SELECT '|' + rt.TableName
            FROM sop.EtlTables rt
                INNER JOIN sop.TableLoadGroupMap map
                    ON map.TableId = rt.TableId
            WHERE rt.Active = 1
                  AND rt.PackageSystemId = @PackageSystemId
                  AND rt.LoadParameters = @LoadParameters
                  AND map.TableLoadGroupId = @TableLoadGroupId
            ORDER BY rt.TableName
            FOR XML PATH('')
        )                        AS VARCHAR(MAX)),
                                  1,
                                  1,
                                  ''
                                 );

        IF (LEN(ISNULL(@TableList, '')) = 0)
            RAISERROR(
                         'Unable to process an empty table list.  Either @TableList or @TableLoadGroupId are required. If one of these was specified, Insure all required parameters are being passed in.',
                         16,
                         1
                     );
    END;

    IF EXISTS
    (
        SELECT 1
        FROM STRING_SPLIT(@TableList, '|') ss
            LEFT JOIN sop.EtlTables t
                ON t.TableName = ss.value
                   AND t.PackageSystemId = @PackageSystemId
        WHERE (
                  t.TableName IS NULL
                  OR t.LoadParameters <> @LoadParameters
                  OR
                  (
                      t.Active = 0
                      AND @TestFlag = 0
                  )
              )
    )
    BEGIN
        IF (@Debug >= 1)
        BEGIN
            SELECT ss.value,
                   ExpectedLoadParameters = t.LoadParameters,
                   ActualLoadParameters = @LoadParameters,
                   t.Active,
                   t.PackageSystemId,
                   ErrorReason = CASE
                                     WHEN t.TableName IS NULL THEN
                                         'Table does not exist in dbo.EtlTables'
                                     WHEN t.LoadParameters <> @LoadParameters THEN
                                         'Invalid load parameters for table.'
                                     WHEN OBJECT_ID(t.TableName) IS NULL THEN
                                         'Table does not exist!'
                                     WHEN t.Active = 0
                                          AND @TestFlag = 0 THEN
                                         'Can not queue disabled dbo.EtlTables with TestFlag=0.  Review Active flag in dbo.EtlTables'
                                     ELSE
                                         'UNKNOWN'
                                 END
            FROM STRING_SPLIT(@TableList, '|') ss
                LEFT JOIN sop.EtlTables t
                    ON t.TableName = ss.value
                       AND t.PackageSystemId = @PackageSystemId
            WHERE (
                      t.TableName IS NULL
                      OR t.LoadParameters <> @LoadParameters
                  );
        END;

        RAISERROR(
                     'Invalid table passed in.  Please insure all tables exist in dbo.EtlTables and have the correct @LoadParameters specified.  Requeue with @Debug=1 for more details.',
                     16,
                     1
                 );
    END;

    SELECT @CurrentAction = 'Adding to dbo.EtlBatchRuns';

    INSERT INTO sop.BatchRun
    (
        PackageSystemId,
        ParameterList,
        LoadParameters,
        BatchRunStatusId,
        TableList,
        TestFlag
    )
    VALUES
    (   @PackageSystemId, @ParameterList, @LoadParameters, 1, -- Ready  
        @TableList, @TestFlag);
    SELECT @BatchRunID = SCOPE_IDENTITY();

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Info',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @Message,
                                  @Status = 'END',
                                  @Exception = NULL,
                                  @BatchId = @BatchId;


    RETURN 0;
END TRY
BEGIN CATCH
    SELECT @ReturnErrorMessage
        = 'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
          + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
          + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
          + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Error',
                                  @Category = 'MpsEtl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @CurrentAction,
                                  @Status = 'ERROR',
                                  @Exception = @ReturnErrorMessage,
                                  @BatchId = @BatchId;

    -- re-throw the error  
    THROW;

END CATCH;


