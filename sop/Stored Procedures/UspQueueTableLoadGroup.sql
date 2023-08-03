
CREATE   PROC [sop].[UspQueueTableLoadGroup]
    @Debug TINYINT = 0,
    @BatchId VARCHAR(100) = NULL,
    @TableLoadGroupIdList VARCHAR(2),
	@EsdVersionId INT=0,
    @TestFlag INT = 0
AS

----/*********************************************************************************      

---- Purpose: Queues records for the given @TableLoadGroups      
---- Parameters:      
----  @Debug:      
----            1 - Will output some basic info with timestamps      
----            2 - Will output everything from 1, as well as rowcounts      

---- Return Codes:        
----   0   = Success      
----            < 0 = Error      
----            > 0 (No warnings for this SP, should never get a returncode > 0)      

----    Date        User            Description      
----***********************************************************************************************************************************************************      
---- 2023-06-16     atairumx        Initial Release      
---- 2023-07-12     atairumx        Include Load Revenue table  
---- 2023-07-13     vitorsix        Include Load Sales Block  
---- 2023-07-14     fjunio2x        Include TableLoadGroupId =  5 - Load tables triggered by new Esd POR Version  
---- 2023-07-17     fjunio2x        Include TableLoadGroupId =  6 - Load Billings into table sop.ActualSales  
---- 2023-07-18     fjunio2x        Include TableLoadGroupId =  7 - Load ConsensusDemand into table sop.DemandForecast   
---- 2023-07-14     vitorsix        Include TableLoadGroupId =  8 - Load Capacity  
---- 2023-07-17     vitorsix        Include TableLoadGroupId =  9 - Load ProdCoCustomerOrderVolumeOpenConfirmed  
---- 2023-07-18     vitorsix        Include TableLoadGroupId = 10 - Load ProdCoCustomerOrderVolumeOpenUnconfirmed   
---- 2023-07-19     atairumx        Include TableLoadGroupId = 11 - Load ProdCoRequestBeFull
---- 2023-07-20     caiosanx        Include TableLoadGroupId = 12 - Load FullTargetUnconstrainedSolve
---- 2023-07-24     hmanentx        Include TableLoadGroupId = 13 - Load MfgSupplyForecast
---- 2023-07-24     fjunio2x        Include parameter @EsdVersionId and changed TableLoadGroupId 5 to only set the parameters for sop.UspQueueBatchRun
---- 2023-07-27     hmanentx        Altering the condition to run the TableLoadGroupId = 13 to just run in case of new EsdVersion
---- 2023-07-28     rmiralhx        Include TableLoadGroupId = 14 - Load Corridor
---- 2023-07-28     fjunio2x        Include TableLoadGroupId = 4 - Load tables triggered by new Esd POR Version - UNCONSTRAINED   
---- 2023-07-28     fjunio2x        Exclude TableLoadGroupId = 13 - Tables included in Group 5, same trigger  
---- 2023-08-01     fjunio2x        Include TableLoadGroupId = 17 -  Load tables triggered by new Esd Version - UNCONSTRAINED - With parameter GlobalConfig
---- 2023-08-01     jcsolano        Include TableLoadGroupId = 18 - Load tables triggered by MfgSupplyActual  
----***********************************************************************************************************************************************************      
--EXEC sop.UspQueueTableLoadGroup      
--    @Debug = 1      
--  --, @BatchId = ''      
--  , @TableLoadGroupIdList = '1'      
--  , @TestFlag = 0        
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
    DECLARE @BatchRunId INT;
    DECLARE @SourceVersionId INT;
    DECLARE @PackageSystemNm VARCHAR(25);
    DECLARE @BatchRunList VARCHAR(MAX);
    DECLARE @Datetime VARCHAR(100);
    DECLARE @GlobalConfig INT;
    DECLARE @TableList VARCHAR(8000);

    DECLARE @BatchRuns TABLE
    (
        BatchRunID INT NOT NULL PRIMARY KEY CLUSTERED
    );

    DECLARE @TablesToLoad TABLE
    (
        TableName VARCHAR(500) NOT NULL,
        PackageSystemId INT NOT NULL,
        PRIMARY KEY CLUSTERED (
                                  TableName,
                                  PackageSystemId
                              )
    );

    ------------------------------------------------------------------------------------------------      
    -- Perform work ********************************************************************************      
    SELECT @CurrentAction = 'Validation';

    IF (@Debug >= 1)
    BEGIN
        SELECT rt.TableId,
               rt.TableName,
               rt.LoadParameters,
               rt.Description,
               rt.Keywords,
               rt.Active,
               rt.PurgeScript,
               rt.PackageSystemId,
               rt.StagingTables,
               rt.CreatedOn,
               rt.CreatedBy,
               rt.UpdatedOn,
               rt.UpdatedBy,
               map.TableLoadGroupId,
               map.TableId,
               map.CreatedOn,
               map.CreatedBy,
               tlg.TableLoadGroupId,
               tlg.TableLoadGroupName,
               tlg.GroupType,
               tlg.Description,
               tlg.CreatedOn,
               tlg.CreatedBy,
               @TableLoadGroupIdList TableLoadGroupId
        FROM sop.EtlTables rt
            INNER JOIN sop.TableLoadGroupMap map
                ON map.TableId = rt.TableId
            INNER JOIN sop.TableLoadGroup tlg
                ON tlg.TableLoadGroupId = map.TableLoadGroupId
                   AND tlg.TableLoadGroupId = @TableLoadGroupIdList;
    END;

    SELECT @CurrentAction = 'Starting work';


    -- Get tables to load, based on parameter @TableLoadGroupIdList  
    SELECT @CurrentAction = 'Getting tables to load';

    INSERT INTO @TablesToLoad
    (
        TableName,
        PackageSystemId
    )
    SELECT DISTINCT
           rt.TableName,
           rt.PackageSystemId
    FROM sop.EtlTables rt
        INNER JOIN sop.TableLoadGroupMap map
            ON map.TableId = rt.TableId
        INNER JOIN sop.TableLoadGroup tlg
            ON tlg.TableLoadGroupId = map.TableLoadGroupId
    WHERE rt.Active = 1
          AND tlg.TableLoadGroupId = @TableLoadGroupIdList;


    -----------------------------------------------------------------------------------------------      
    -- Load Dimension tables                                                                     --      
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '1'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Dimension';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------      
    -- Load Revenue tables                                                                       --      
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '2'
    BEGIN
        SET @GlobalConfig = 1;
        SET @PackageSystemNm = 'Revenue';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load SVD Dimension tables                                                                 --  
    -----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '3'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Dimension';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load tables triggered by new Esd POR Version - UNCONSTRAINED                              --  
    -----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '4'
    BEGIN
	    SET @SourceVersionId = @EsdVersionId;
        SET @PackageSystemNm = 'Supply';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load tables triggered by new Esd POR Version - CONSTRAINED                                --  
    -----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '5'
    BEGIN	
		SET @SourceVersionId = @EsdVersionId;
        SET @PackageSystemNm = 'Supply';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load Billings                                                                             --  
    -----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '6'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Sales';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load ConsensusDemand                                                                     --  
    ----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '7'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Demand';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------      
    -- Load Capacity                                                                             --     
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '8'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Capacity';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------      
    -- Load ProdCoCustomerOrderVolumeOpenConfirmed                                               --    
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '9'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Sales';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------      
    -- Load ProdCoCustomerOrderVolumeOpenUnconfirmed                                             --  
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '10'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Sales';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------     
    -- Load ProdCoRequestBeFull                                                                  --      
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '11'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Supply';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load Full Target Solve Unconstrained tables                                               --  
    -----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '12'
    BEGIN
        SET @GlobalConfig = 1;
        SET @PackageSystemNm = 'Supply';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------        
    -- Load Corridor                                                                             --  
    -----------------------------------------------------------------------------------------------        
    IF @TableLoadGroupIdList = '14'
    BEGIN
        SET @Datetime = SYSDATETIME();
        SET @PackageSystemNm = 'Corridor';
        SET @BatchRunId = 1;
    END;

    -----------------------------------------------------------------------------------------------      
    -- Load tables triggered by new Esd Version - UNCONSTRAINED - With parameter GlobalConfig    --  
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '17'
    BEGIN
        SET @GlobalConfig = 1;
        SET @PackageSystemNm = 'Supply';
        SET @BatchRunId = 1;
    END;    
	
    -----------------------------------------------------------------------------------------------      
    -- Load tables triggered by MfgSupplyActual    --  
    -----------------------------------------------------------------------------------------------      
    IF @TableLoadGroupIdList = '18'
    BEGIN
        SET @GlobalConfig = 1;
        SET @PackageSystemNm = 'Supply';
        SET @BatchRunId = 1;
    END;    

    -----------------------------------------------------------------------------------------------     
    -- Queue BatchRun                                                                            --      
    -----------------------------------------------------------------------------------------------      
    IF @BatchRunId = 1
    BEGIN
        EXEC sop.UspQueueBatchRun @Debug = @Debug,
                                  @BatchId = @BatchId,
                                  @PackageSystemName = @PackageSystemNm,
                                  @SourceVersionId = @SourceVersionId,
                                  @Datetime = @Datetime,
                                  @GlobalConfig = @GlobalConfig,
                                  @TableLoadGroupId = @TableLoadGroupIdList,
                                  @TestFlag = @TestFlag,
                                  @BatchRunID = @BatchRunId OUTPUT;

        INSERT INTO @BatchRuns
        (
            BatchRunID
        )
        VALUES
        (@BatchRunId);
    END;

    -----------------------------------------------------------------------------------------------      

    IF (@Debug >= 1)
    BEGIN
        SELECT Expected_PackageSystemId = tl.PackageSystemId,
               Expected_TableName = tl.TableName,
               Actual_PackageSystemId = x.PackageSystemId,
               Actual_TableName = x.TableName
        FROM @TablesToLoad tl
            FULL OUTER JOIN
            (
                SELECT br.PackageSystemId,
                       TableName = ss.value
                FROM @BatchRuns bt
                    INNER JOIN sop.BatchRun br
                        ON br.BatchRunId = bt.BatchRunID
                    CROSS APPLY STRING_SPLIT(br.TableList, '|') ss
            ) x
                ON x.TableName = tl.TableName
                   AND x.PackageSystemId = tl.PackageSystemId
        ORDER BY ISNULL(tl.PackageSystemId, x.PackageSystemId),
                 ISNULL(tl.TableName, x.TableName);
    END;

    IF EXISTS
    (
        SELECT 1
        FROM @TablesToLoad tl
            FULL OUTER JOIN
            (
                SELECT br.PackageSystemId,
                       TableName = ss.value
                FROM @BatchRuns bt
                    INNER JOIN sop.BatchRun br
                        ON br.BatchRunId = bt.BatchRunID
                    CROSS APPLY STRING_SPLIT(br.TableList, '|') ss
            ) x
                ON x.TableName = tl.TableName
                   AND x.PackageSystemId = tl.PackageSystemId
        WHERE (
                  tl.PackageSystemId IS NULL
                  OR x.PackageSystemId IS NULL
              )
    )
    BEGIN
        RAISERROR('Tables queued did not match tables expected', 16, 1);
    END;

    SELECT @BatchRunList = CAST(STUFF(
                                (
                                    SELECT '|' + CAST(br.BatchRunID AS VARCHAR(MAX))
                                    FROM @BatchRuns br
                                    FOR XML PATH('')
                                ),
                                1,
                                1,
                                ''
                                     ) AS VARCHAR(MAX));

    RAISERROR('BatchRuns: %s', 0, 1, @BatchRunList);

    SELECT @Message = 'Queue BatchRuns: ' + @BatchRunList;

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

