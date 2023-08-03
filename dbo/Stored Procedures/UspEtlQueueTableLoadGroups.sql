  
  
  
CREATE    PROC [dbo].[UspEtlQueueTableLoadGroups]  
      @Debug TINYINT = 0  
 , @BatchId VARCHAR(100) = NULL  
 , @TableLoadGroupIdList VARCHAR(1000)  
 , @TestFlag INT = 0  
AS  
/*********************************************************************************  
    Author:         Ben Sala  
  
    Purpose:        Queues records for the given @TableLoadGroups  
  
    Called by:      SSMS  
  
    Result sets:    None  
  
    Parameters:  
                    @Debug:  
                        1 - Will output some basic info with timestamps  
                        2 - Will output everything from 1, as well as rowcounts  
  
    Return Codes:   0   = Success  
                    < 0 = Error  
                    > 0 (No warnings for this SP, should never get a returncode > 0)  
  
    Exceptions:     None expected  
  
    Date        User      Description  
***************************************************************************-  
 2020-11-17  Ben Sala  Initial Release  
 2021-02-16 Ben Sala  Adding load group 105  
 2021-03-22  Ben Sala        Removed debug code for TableLoadGroup 107  
 2021-04-30 Ben Sala  Adding load group 108  
 2022-08-30  Juan Solano     Adding load groups 109, 110  
 2023-01-11  AMR\caiosanx    Changing load group 109 logic  
 2023-01-11  AMR\caiosanx    Adding load group 114  
 2023-04-11  AMR\rmiralhx    Adding load group 113  
 2023-05-08  AMR\fjunio2x    Adding load group 115  
 2023-07-06  AMR\rmiralhx    Add loop to group 115  
 2023-07-27  AMR\fgarc20x	 Remove WFDS calls (TableGroupId 103)
*********************************************************************************  
EXEC dbo.UspEtlQueueTableLoadGroups  
    @Debug = 1  
  --, @BatchId = ''  
  , @TableLoadGroupIdList = '102'  
  , @TestFlag = 0  
  
  
*********************************************************************************/  
  
  
SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;  
  
SET NUMERIC_ROUNDABORT OFF;  
  
BEGIN TRY  
    -- Error and transaction handling setup ********************************************************  
    DECLARE  
        @ReturnErrorMessage VARCHAR(MAX)  
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)  
      , @CurrentAction      VARCHAR(4000)  
      , @DT                 VARCHAR(50) = SYSDATETIME()  
   , @Message   VARCHAR(MAX);  
  
    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';  
  
 IF(@BatchId IS NULL)   
  SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();  
  
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
 DECLARE   
    @PriorYearMm INT  
  , @PriorYearWw INT  
  , @CurrentYearWw INT  
  , @BatchRunId INT  
  , @CurrentSnapshotId INT  
  , @SourceApplicationName VARCHAR(25)  
  , @SourceVersionId INT  
  , @RowCount INT  
  , @BatchRunList VARCHAR(MAX)  
  , @Datetime      VARCHAR(1000)  
  , @TableList VARCHAR(8000)  
  ;  
  
 DECLARE @MPSSourceVersions TABLE   
  (SourceApplicationName VARCHAR(25) NOT NULL, SourceApplicationId INT NOT NULL, SourceVersionID INT NOT NULL, Processed BIT NOT NULL DEFAULT 0  
  , PRIMARY KEY CLUSTERED (SourceApplicationName, SourceVersionID)  
  );  
  
 DECLARE @BatchRuns TABLE (BatchRunID INT NOT NULL PRIMARY KEY CLUSTERED);  
  
 DECLARE @LoadGroups TABLE (TableLoadGroupId INT NOT NULL PRIMARY KEY CLUSTERED); -- HAS THE LIST OF GROUPS TO BE LOADED  
  
 DECLARE @TablesToLoad TABLE   
  (SourceApplicationId INT NOT NULL, TableName VARCHAR(500) NOT NULL  
  , TableId INT NOT NULL  
  , PRIMARY KEY CLUSTERED (SourceApplicationId, TableName)  
  );  
  
    ------------------------------------------------------------------------------------------------  
    -- Perform work ********************************************************************************  
 SELECT @CurrentAction = 'Validation';  
 INSERT INTO @LoadGroups (TableLoadGroupId)  
 SELECT list.value FROM STRING_SPLIT(@TableLoadGroupIdList, '|') list;  
  
 IF EXISTS ( -- CHECKS IF WE HAVE DONT HAVE VALUES IN THE TABLEGROUPS  
  SELECT 1  
  FROM @LoadGroups lg  
  LEFT JOIN dbo.EtlTableLoadGroups reflg -- LIST OF TABLE GROUPS  
   ON reflg.TableLoadGroupId = lg.TableLoadGroupId  
   AND reflg.GroupType <> 'ESD'  
  WHERE reflg.TableLoadGroupId IS NULL -- CHECKS IF ITS MISSINGS  
  )  
 BEGIN  
  IF(@Debug >= 1)  
  BEGIN  
      SELECT lg.TableLoadGroupId  
    , Problem =    
     CASE  
      WHEN reflg.GroupType = 'ESD' THEN 'ESD groups are not currently supported by this SP'  
      WHEN reflg.TableLoadGroupId IS NULL  THEN 'TableLoadGroupID does not exist in dbo.EtlTableLoadGroups'  
      ELSE 'Valid TableLoadGroupId'  
     END  
    , reflg.TableLoadGroupName  
    , reflg.GroupType  
   FROM @LoadGroups lg  
   LEFT JOIN dbo.EtlTableLoadGroups reflg  
    ON reflg.TableLoadGroupId = lg.TableLoadGroupId  
   ORDER BY  
    lg.TableLoadGroupId;  
  
  END  
  
  RAISERROR('InvalidTableLoadGroupId passed in!',16,1); -- REAISE ERROR IF TABLE GROUP NOT FOUND   
 END  
  
  
  
 IF(@Debug >= 1)  
 BEGIN  
     SELECT *  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  INNER JOIN @LoadGroups l  
   ON l.TableLoadGroupId = tlg.TableLoadGroupId  
  
 END  
  
  
  
 SELECT @CurrentAction = 'Starting work';  

 -- Actual Forecast - OneMps -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 108)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 108;  
  
     SELECT @CurrentAction = 'Loading OneMps load group';  
  
  SELECT @CurrentYearWw = cal.YearWw FROM dbo.Intelcalendar cal WHERE SYSDATETIME() >= cal.StartDate AND SYSDATETIME() < cal.EndDate;  
  IF(@Debug >= 1)  
  BEGIN  
      RAISERROR('TableLoadGroupId: 108 @CurrentYearWw: %d',0,1,@CurrentYearWw);  
  END  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'OneMps'  
    , @YearWw = @CurrentYearWw  
    , @TableLoadGroupId = 108  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
 END  
  
  
  
 -- Actuals -----------------------------------------------------------------------  
  
  IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 101)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 101;  
  
     SELECT @CurrentAction = 'Loading Actuals load group';  
  
  --SELECT @PriorYearMm = cal.YearMonth FROM dbo.Intelcalendar cal WHERE DATEADD(MONTH,-1,SYSDATETIME()) >= cal.StartDate AND DATEADD(MONTH,-1,SYSDATETIME()) < cal.EndDate;  
  SELECT @PriorYearWw = cal.YearWw FROM dbo.Intelcalendar cal WHERE DATEADD(WEEK,-1,SYSDATETIME()) >= cal.StartDate AND DATEADD(WEEK,-1,SYSDATETIME()) < cal.EndDate;  
  IF(@Debug >= 1)  
  BEGIN  
      RAISERROR('TableLoadGroupId: 101 @PriorYearMm: %d  @PriorYearWw: %d',0,1,@PriorYearMm, @PriorYearWw);  
  END  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'AirSQL'  
    , @YearWw = @PriorYearWw  
    , @TableLoadGroupId = 101  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  
  /*EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'AirSQL'  
    , @YearMm = @PriorYearMm  
    , @TableLoadGroupId = 101  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);*/  
 END  
  
  
/*  
  
 HANA ACTUALS  
  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 101)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 101;  
  
     SELECT @CurrentAction = 'Loading Actuals load group';  
  
  SELECT @PriorYearMm = cal.YearMonth FROM dbo.Intelcalendar cal WHERE DATEADD(MONTH,-1,SYSDATETIME()) >= cal.StartDate AND DATEADD(MONTH,-1,SYSDATETIME()) < cal.EndDate;  
  SELECT @PriorYearWw = cal.YearWw FROM dbo.Intelcalendar cal WHERE DATEADD(WEEK,-1,SYSDATETIME()) >= cal.StartDate AND DATEADD(WEEK,-1,SYSDATETIME()) < cal.EndDate;  
  IF(@Debug >= 1)  
  BEGIN  
      RAISERROR('TableLoadGroupId: 101 @PriorYearMm: %d  @PriorYearWw: %d',0,1,@PriorYearMm, @PriorYearWw);  
  END  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    --, @SourceApplicationName = 'AirSQL'  
    , @SourceApplicationName = 'Hana'  
    , @YearWw = @PriorYearWw  
    , @TableLoadGroupId = 101  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    --, @SourceApplicationName = 'AirSQL'  
    , @SourceApplicationName = 'Hana'  
    , @YearMm = @PriorYearMm  
    , @TableLoadGroupId = 101  
    , @TestFlag = @TestFlag  
    --, @BatchRunId = @BatchRunId OUTPUT  
    ;  
  
  --INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
 END*/  
/*  
 -------------------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 107)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 107;  
  
     SELECT @CurrentAction = 'Loading Actuals load group';  
  
  SELECT @PriorYearMm = cal.YearMonth FROM dbo.Intelcalendar cal WHERE DATEADD(MONTH,-1,SYSDATETIME()) >= cal.StartDate AND DATEADD(MONTH,-1,SYSDATETIME()) < cal.EndDate;  
  SELECT @PriorYearWw = cal.YearWw FROM dbo.Intelcalendar cal WHERE DATEADD(WEEK,-1,SYSDATETIME()) >= cal.StartDate AND DATEADD(WEEK,-1,SYSDATETIME()) < cal.EndDate;  
  IF(@Debug >= 1)  
  BEGIN  
      RAISERROR('TableLoadGroupId: 107 @PriorYearMm: %d  @PriorYearWw: %d',0,1,@PriorYearMm, @PriorYearWw);  
  END  
  SELECT @Debug, @BatchId, 'AirSQL', @PriorYearWw,107,@TestFlag, @BatchRunId OUTPUT  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'AirSQL'  
    , @YearWw = @PriorYearWw  
    , @TableLoadGroupId = 107  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
 END  
 --x  
 SELECT @CurrentAction = 'Starting work';  
  
*/  
 -- Snapshot data -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 105)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 105;  
  
     SELECT @CurrentAction = 'Loading Snapshot load group';  
  
  SELECT distinct @tablelist = TableName from @TablesToLoad;  
  
  EXEC [dbo].[UspETLFetchMinimunTimeDate] @TableList = @TableList, @Datetime = @Datetime OUTPUT;  
  
  --SELECT @CurrentSnapshotId = cal.YearWw FROM dbo.Intelcalendar cal WHERE SYSDATETIME() BETWEEN cal.StartDate AND cal.EndDate;  
  IF(@Debug >= 1)  
  BEGIN  
      RAISERROR('TableLoadGroupId: 105 @Datetime: %s',0,1, @Datetime);  
  END  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'Denodo'  
    , @TableLoadGroupId = 105  
    , @Datetime = @Datetime  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT  
    ;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
 END  
  
  -- Datetime Actuals -----------------------------------------------------------------------  
IF EXISTS (SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 109)      
BEGIN      
    SELECT @CurrentAction = 'Getting tables to load';      
      
    INSERT INTO @TablesToLoad (SourceApplicationId,TableName,TableId)      
    SELECT rt.SourceApplicationId,      
           rt.TableName,      
           rt.TableId      
    FROM dbo.EtlTables rt      
        INNER JOIN dbo.EtlTableLoadGroupMap map      
            ON map.TableId = rt.TableId      
        INNER JOIN dbo.EtlTableLoadGroups tlg      
            ON tlg.TableLoadGroupId = map.TableLoadGroupId      
    WHERE rt.Active = 1      
          AND tlg.TableLoadGroupId = 109;      
      
    SELECT @CurrentAction = 'Loading Actuals load group';      
      
    EXEC [dbo].[UspETLFetchMinimunTimeDate] @TableList = @TableList, @Datetime = @Datetime OUTPUT; -- ASSIGN A VALUE FOR @Datetime      
    SELECT @PriorYearWw = cal.YearWw FROM dbo.IntelCalendar cal WHERE DATEADD(WEEK, -1, SYSDATETIME()) >= cal.StartDate AND DATEADD(WEEK, -1, SYSDATETIME()) < cal.EndDate; -- ASSIGN A VALUE FOR @PriorYearWw      
      
    IF (@Debug >= 1)      
    BEGIN      
        RAISERROR('TableLoadGroupId: 101 @PriorYearMm: %d  @PriorYearWw: %d', 0, 1, @PriorYearMm, @PriorYearWw);      
    END;      
      
    EXEC dbo.UspEtlQueueBatchRun @Debug = @Debug,      
                                 @BatchId = @BatchId,      
                                 @SourceApplicationName = 'Hana',      
                                 @Datetime = @Datetime,      
                                 @TableLoadGroupId = 109,      
                                 @TestFlag = @TestFlag,      
                                 @BatchRunID = @BatchRunId OUTPUT;      
      
    INSERT INTO @BatchRuns(BatchRunID) VALUES (@BatchRunId);      
      
    EXEC dbo.UspEtlQueueBatchRun @Debug = @Debug,      
                                 @BatchId = @BatchId,      
                                 @SourceApplicationName = 'Hana',      
                                 @YearWw = @PriorYearWw,      
                                 @TableLoadGroupId = 109,      
                                 @TestFlag = @TestFlag,      
                                 @BatchRunID = @BatchRunId OUTPUT;      
    
    INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);      
END;    
     
 -- Denodo Hierarchies -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 110)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  LEFT JOIN   
   (SELECT  
    DISTINCT TableName = ss.value   
    FROM dbo.EtlBatchRuns  
    CROSS APPLY STRING_SPLIT(TableList, '|') ss  
    WHERE BatchRunStatusId IN (1,2,3)  
    AND TestFlag = @TestFlag  
   ) br  
  ON br.TableName = rt.TableName  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 110  
   AND br.TableName IS NULL;  
  
     SELECT @CurrentAction = 'Loading Denodo Hierarchies load group';  
  IF(@Debug >= 1)  
  BEGIN  
      RAISERROR('TableLoadGroupId: 110 @Datetime: %s',0,1, @Datetime);  
  END  
  
  SELECT @ROWCOUNT = COUNT(1) FROM @TablesToLoad;  
  IF (@ROWCOUNT > 0)  
   BEGIN  
    EXEC dbo.UspEtlQueueBatchRun  
     @Debug = @Debug  
      , @BatchId = @BatchId  
      , @SourceApplicationName = 'Denodo'  
      , @TableLoadGroupId = 110  
      , @TestFlag = @TestFlag  
      , @GlobalConfig = 1  
      , @BatchRunId = @BatchRunId OUTPUT  
      ;  
  
    INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
   END  
   ELSE   
    RAISERROR('Batch Run already on queue list.',1,1);  
  
 END  
   
 -- SnOPDemandForecast  -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 111)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  LEFT JOIN   
   (SELECT  
    DISTINCT TableName = ss.value   
    FROM dbo.EtlBatchRuns  
    CROSS APPLY STRING_SPLIT(TableList, '|') ss  
    WHERE BatchRunStatusId IN (1,2,3)  
    AND TestFlag = @TestFlag  
   ) br  
  ON br.TableName = rt.TableName  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 111  
   AND br.TableName IS NULL;  
  
  
  SELECT @ROWCOUNT = COUNT(1) FROM @TablesToLoad;  
    
  IF (@ROWCOUNT > 0)  
   BEGIN   
    SELECT distinct @tablelist = TableName from @TablesToLoad;  
  
    DECLARE @MAXID INT;  
    DECLARE @TableName VARCHAR(1000);  
    DECLARE @ID INT = 1;  
  
    CREATE TABLE #Tables  
    (  
     Id INT IDENTITY(1, 1),  
     TableName VARCHAR(MAX)  
    );  
  
    INSERT INTO #Tables(TableName)  
    SELECT TableName FROM @TablesToLoad;  
    SELECT @MAXID = MAX(ID) FROM #Tables;  
  
    WHILE @ID <= @MAXID  
    BEGIN   
     SELECT @TableName=TableName FROM #Tables WHERE ID = @ID;  
     
     EXEC [dbo].[UspETLFetchMinimunTimeDate] @TableList = @TableName, @Datetime = @Datetime OUTPUT;  
     
     EXEC dbo.UspEtlQueueBatchRun  
     @Debug = @Debug  
      , @BatchId = @BatchId  
      , @SourceApplicationName = 'Denodo'  
      , @TableList = @TableName  
      , @TestFlag = @TestFlag  
      , @Datetime = @Datetime  
      , @BatchRunId = @BatchRunId OUTPUT  
      ;  
      INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
      SET @Datetime = NULL;  
      SET @ID +=1  
    END   
    DROP TABLE #Tables;  
   END   
  ELSE   
   RAISERROR('Batch Run already on queue list.',1,1);  
  
 END  
  
 -- SOPFiscalCalendar  -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 112)  
 BEGIN  
    
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 112;  
  
     SELECT @CurrentAction = 'Loading SOPFiscalCalendar load group';  
  SELECT distinct @tablelist = TableName from @TablesToLoad;  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'Denodo'  
    , @TableList = @tablelist  
    , @GlobalConfig = 1  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  
 END   
  
 -- SnOPCompassMRPFabRouting  -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 113)  
 BEGIN  
    
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 113;  
  
     SELECT @CurrentAction = 'Load SnOPCompassMRPFabRouting data depending on Hana job';  
  SELECT distinct @tablelist = TableName from @TablesToLoad;  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'Hana'  
    , @EsdVersionId = 123  
    , @CompassPublishLogId = 123  
    , @TableList = @tablelist  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  
 END   
  
 -- Actual Billings -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 114)  
 BEGIN  
    
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId,  
      rt.TableName,  
      rt.TableId  
  FROM dbo.EtlTables rt  
   INNER JOIN dbo.EtlTableLoadGroupMap map  
    ON map.TableId = rt.TableId  
   INNER JOIN dbo.EtlTableLoadGroups tlg  
    ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
     AND tlg.TableLoadGroupId = 114;  
  
     SELECT @CurrentAction = 'Loading Actual Billings load group';  
  SELECT DISTINCT @tablelist = TableName FROM @TablesToLoad;  
  SELECT @CurrentYearWw = cal.YearWw FROM dbo.Intelcalendar cal WHERE SYSDATETIME() >= cal.StartDate AND SYSDATETIME() < cal.EndDate;  
  
  EXEC dbo.UspEtlQueueBatchRun @Debug = @Debug,  
                             @BatchId = @BatchId,  
                             @SourceApplicationName = 'Denodo',  
                             @YearWw = @CurrentYearWw,  
        @TableList = @TableList,  
                             @TestFlag = @TestFlag,  
                             @BatchRunID = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID)   
  VALUES(@BatchRunId);  
 END   
  
  
 -- StgDiePrepItemsMap -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 115)  
 BEGIN  
    
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId,  
      rt.TableName,  
      rt.TableId  
  FROM dbo.EtlTables rt  
   INNER JOIN dbo.EtlTableLoadGroupMap map  
    ON map.TableId = rt.TableId  
   INNER JOIN dbo.EtlTableLoadGroups tlg  
    ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
     AND tlg.TableLoadGroupId = 115;  
    
  SELECT @ROWCOUNT = COUNT(1) FROM @TablesToLoad;  
    
  IF (@ROWCOUNT > 0)  
   BEGIN   
    SELECT distinct @tablelist = TableName from @TablesToLoad;  
  
    DECLARE @MAXID_DiePrep INT;  
    DECLARE @TableName_DiePrep VARCHAR(1000);  
    DECLARE @ID_DiePrep INT = 1;  
  
    CREATE TABLE #Tables_DiePrep  
    (  
     Id INT IDENTITY(1, 1),  
     TableName VARCHAR(MAX),  
     TableId INT,  
     SourceApplicationId INT  
    );  
  
    INSERT INTO #Tables_DiePrep (TableName, TableId, SourceApplicationId)  
    SELECT TableName, TableId, SourceApplicationId FROM @TablesToLoad;  
    SELECT @MAXID_DiePrep = MAX(Id) FROM #Tables_DiePrep;  
  
    WHILE @ID_DiePrep <= @MAXID_DiePrep  
    BEGIN   
     SELECT @TableName_DiePrep=TableName FROM #Tables_DiePrep WHERE ID = @ID_DiePrep;  
     
     SELECT @CurrentAction = 'Loading StgDiePrepItemsMap load group';  
     SELECT @CurrentYearWw = cal.YearWw FROM dbo.Intelcalendar cal WHERE SYSDATETIME() >= cal.StartDate AND SYSDATETIME() < cal.EndDate;  
  
     DECLARE @SourceApplicationName_DiePrep NVARCHAR(100);  
     SELECT @SourceApplicationName_DiePrep = S.SourceApplicationName FROM #Tables_DiePrep D LEFT JOIN EtlTables T ON D.TableId = T.TableId LEFT JOIN EtlSourceApplications S ON D.SourceApplicationId = S.SourceApplicationId WHERE ID = @ID_DiePrep;  
  
     EXEC dbo.UspEtlQueueBatchRun @Debug = @Debug,  
           @BatchId = @BatchId,  
           @SourceApplicationName = @SourceApplicationName_DiePrep,  
           @YearWw = @CurrentYearWw,      
           @TableList = @TableName_DiePrep,  
           @TestFlag = @TestFlag,  
           @BatchRunID = @BatchRunId OUTPUT;  
       
     INSERT INTO @BatchRuns (BatchRunID) VALUES(@BatchRunId);  
     SET @ID_DiePrep +=1  
    END   
    DROP TABLE #Tables_DiePrep;  
   END   
  ELSE   
   RAISERROR('Batch Run already on queue list.',1,1);       
 END   
 -----------------------------------------------------------------------  
  
  
/*  
 -- Mappings -----------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 104)  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 104;  
  
     SELECT @CurrentAction = 'Loading Map load group';  
  
  EXEC dbo.UspEtlQueueBatchRun  
      @Debug = @Debug  
    , @BatchId = @BatchId  
    , @SourceApplicationName = 'Denodo'  
    , @GlobalConfig = 1  
    , @TableLoadGroupId = 104  
    , @TestFlag = @TestFlag  
    , @BatchRunId = @BatchRunId OUTPUT;  
  
  INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  
  -- They disable all the Mapping tables at times.   
  IF EXISTS (SELECT 1 FROM @TablesToLoad t INNER JOIN dbo.EtlTables rt ON rt.TableId = t.TableId WHERE rt.LoadParameters LIKE '%Map%')  
  BEGIN  
   EXEC dbo.UspEtlQueueBatchRun  
    @Debug = @Debug  
     , @BatchId = @BatchId  
     , @SourceApplicationName = 'SDRA DataMart'  
     , @Map = 1  
     , @TableLoadGroupId = 104  
     , @TestFlag = @TestFlag  
     , @BatchRunId = @BatchRunId OUTPUT;  
  
   INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  END  
  
 END  
  
  
 -- MPS ---------------------------------------------------------------------------------------------  
 IF EXISTS(SELECT 1 FROM @LoadGroups WHERE TableLoadGroupId = 102)   
  AND EXISTS (SELECT 1 FROM dbo.SourceVersions WHERE Reload = 1 AND SourceApplicationId = 5) -- Only supports OneMps on this release  
 BEGIN  
  SELECT @CurrentAction = 'Getting tables to load';  
  
  INSERT INTO @TablesToLoad (SourceApplicationId, TableName, TableId)  
  SELECT rt.SourceApplicationId  
   , rt.TableName  
   , rt.TableId  
  FROM dbo.EtlTables rt  
  INNER JOIN dbo.EtlTableLoadGroupMap map  
   ON map.TableId = rt.TableId  
  INNER JOIN dbo.EtlTableLoadGroups tlg  
   ON tlg.TableLoadGroupId = map.TableLoadGroupId  
  WHERE rt.Active = 1  
   AND tlg.TableLoadGroupId = 102  
   AND rt.SourceApplicationId = 5; -- Only load OneMPS For now  
  /* Changed to use dbo.SourceVersions Reload flag instead *************************  
  -- IsMps Versions ------------------------------------------------------  
  IF EXISTS(SELECT 1 FROM @TablesToLoad WHERE SourceApplicationId = 2)  
  BEGIN  
   INSERT INTO @MPSSourceVersions (SourceApplicationName, SourceVersionID)  
   SELECT  
    SourceApplicationName = 'IsMps'              
     , SourceVersionId = v.VersionId    
   FROM [ISMPSREPLDATA].[ISMPS_Reporting].[dbo].[t_ismps_version] v  
   WHERE v.ActiveFlag = 2  
    AND v.[Is/Was] = 1  
   SELECT @RowCount = @@ROWCOUNT;  
  
   IF(@RowCount <> 1)  
    RAISERROR('IsMps versions expected: 1 Actual: %d',11,1,@RowCount)  
  
  END  
  
  -- FabMps Versions -------------------------------------------------------  
  IF EXISTS(SELECT 1 FROM @TablesToLoad WHERE SourceApplicationId = 1)  
  BEGIN  
      INSERT INTO @MPSSourceVersions (SourceApplicationName, SourceVersionID)  
   SELECT  
    SourceApplicationName = 'FabMps'  
     , SourceVersionId     = v.VersionId  
   FROM FABMPSREPLDATA.SDA_Reporting.dbo.t_sda_version v  
   WHERE  
    v.ActiveFlag = 1  
    AND v.[Is/Was] = 1;  
   SELECT @RowCount = @@ROWCOUNT;  
  
   IF(@RowCount <> 1)  
    RAISERROR('FabMps versions expected: 3 Actual: %d',11,1,@RowCount)  
  END  
  
  -- OneMps versions------------------------------------------------------  
  IF EXISTS(SELECT 1 FROM @TablesToLoad WHERE SourceApplicationId = 5)  
  BEGIN  
   INSERT INTO @MPSSourceVersions (SourceApplicationName, SourceVersionID)  
   SELECT  
    SourceApplicationName = 'OneMps'              
     , SourceVersionId = v.VersionId    
   FROM FABMPSREPLDATA.SDA_Reporting.dbo.t_sda_version v  
   WHERE  
    v.ActiveFlag = 3  
    AND v.[Is/Was] = 1;  
   SELECT @RowCount = @@ROWCOUNT;  
  
   IF(@RowCount <> 1)  
    RAISERROR('OneMps versions expected: 1 Actual: %d',11,1,@RowCount)  
  END  
  */  
  INSERT INTO @MPSSourceVersions (SourceApplicationName, SourceApplicationId, SourceVersionID)  
  SELECT sa.SourceApplicationName  
   , sv.SourceApplicationId  
   , sv.SourceVersionId  
  FROM dbo.SourceVersions sv  
  INNER JOIN dbo.EtlSourceApplications sa  
   ON sa.SourceApplicationId = sv.SourceApplicationId  
  WHERE   
   sv.Reload = 1  
   AND sa.SourceApplicationName = 'OneMps' -- Only supports OneMps on this release  
  
  
  IF(@Debug >= 1)  
  BEGIN  
   SELECT * FROM @MPSSourceVersions  
  END  
  
  WHILE EXISTS (SELECT 1 FROM @MPSSourceVersions WHERE Processed = 0)  
  BEGIN  
      SELECT TOP (1)   
    @SourceApplicationName = SourceApplicationName  
    , @SourceVersionId = SourceVersionId  
   FROM @MPSSourceVersions  
   WHERE Processed = 0;  
  
   IF(@Debug >= 1)  
    RAISERROR('@SourceApplicationName: %s @SourceVersionId: %d',0,1,@SourceApplicationName, @SourceVersionId);  
  
   EXEC dbo.UspEtlQueueBatchRun  
    @Debug = @Debug  
     , @BatchId = @BatchId  
     , @SourceApplicationName = @SourceApplicationName  
     , @SourceVersionId = @SourceVersionId  
     , @TableLoadGroupId = 102  
     , @TestFlag = @TestFlag  
     , @BatchRunId = @BatchRunId OUTPUT;  
  
   INSERT INTO @BatchRuns (BatchRunID) VALUES (@BatchRunId);  
  
   UPDATE @MPSSourceVersions SET Processed = 1 WHERE SourceApplicationName = @SourceApplicationName AND SourceVersionID = @SourceVersionId;  
  
   UPDATE sv SET   
    sv.Reload = 0  
    , sv.MpsReconLoadDate = SYSDATETIME()  
   FROM dbo.SourceVersions sv  
   INNER JOIN @MPSSourceVersions m  
    ON m.SourceApplicationId = sv.SourceApplicationId  
    AND m.SourceVersionID = sv.SourceVersionId  
  
  END  
 END  
 */  
  
  
 SELECT @CurrentAction = 'Validating tables got queued as expected';  
  
 IF(@Debug >= 1)  
 BEGIN  
  SELECT   
   Expected_SourceApplicationId = tl.SourceApplicationId  
   , Expected_TableName = tl.TableName  
   , Actual_SourceApplicationId = x.SourceApplicationId  
   , Actual_TableName = x.TableName  
  FROM @TablesToLoad tl  
  FULL OUTER JOIN   
   (  
   SELECT br.SourceApplicationId  
    , TableName = ss.value  
   FROM @BatchRuns bt  
   INNER JOIN dbo.EtlBatchRuns br  
    ON br.BatchRunId = bt.BatchRunID  
   CROSS APPLY STRING_SPLIT(br.TableList, '|') ss  
   ) x  
   ON x.SourceApplicationId = tl.SourceApplicationId  
   AND x.TableName = tl.TableName  
  --WHERE tl.SourceApplicationId IS NULL OR x.SourceApplicationId IS NULL   
  ORDER BY ISNULL(tl.SourceApplicationId, x.SourceApplicationId)  
   , ISNULL(tl.TableName, x.TableName)  
 END  
   
 IF EXISTS (  
  SELECT   
   1  
  FROM @TablesToLoad tl  
  FULL OUTER JOIN   
   (  
   SELECT br.SourceApplicationId  
    , TableName = ss.value  
   FROM @BatchRuns bt  
   INNER JOIN dbo.EtlBatchRuns br  
    ON br.BatchRunId = bt.BatchRunID  
   CROSS APPLY STRING_SPLIT(br.TableList, '|') ss  
   ) x  
   ON x.SourceApplicationId = tl.SourceApplicationId  
   AND x.TableName = tl.TableName  
  WHERE tl.SourceApplicationId IS NULL OR x.SourceApplicationId IS NULL   
  )  
 BEGIN  
  RAISERROR('Tables queued did not match tables expected',16,1);  
 END  
  
 SELECT @BatchRunList = CAST(STUFF((SELECT '|' + CAST(br.BatchRunID AS VARCHAR(MAX)) FROM @BatchRuns br FOR XML PATH('')),1,1,'') AS VARCHAR(MAX));  
  
 RAISERROR('BatchRuns: %s',0,1,@BatchRunList);  
  
 SELECT @Message = 'Queue BatchRuns: ' + @BatchRunList;  
  
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
   'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50))   
   + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))    
   + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50))    
   + ' Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>')  
   + ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>')   
   + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');  
  
  
 EXEC dbo.UspAddApplicationLog  
    @LogSource = 'Database'  
  , @LogType = 'Error'  
  , @Category = 'MpsEtl'  
  , @SubCategory = @ErrorLoggedBy  
  , @Message = @CurrentAction  
  , @Status = 'ERROR'  
  , @Exception = @ReturnErrorMessage  
  , @BatchId = @BatchId;  
  
    -- re-throw the error  
    THROW;  
  
END CATCH;  
  
  