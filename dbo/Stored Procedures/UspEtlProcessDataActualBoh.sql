  
CREATE   PROC [dbo].[UspEtlProcessDataActualBoh]  
    @Debug TINYINT = 0  
  , @BatchId VARCHAR(100) = NULL  
  , @SourceApplicationName VARCHAR(50)  
  , @BatchRunId INT = -1  
  , @ParameterList VARCHAR(1000) = '*AdHoc*'  
  , @YearWw INT = NULL -- Filter on source OneMps, not sure if this is even needed here.  
AS  
/*********************************************************************************  
    Author:         Ben Sala  
  
    Purpose:        Processes data     
      Source:      dbo.StgActualBoh  
      Destination: dbo.ActualBoh  
  
    Called by:      SSIS - Actuals.dtsx  
  
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
    2023-07-27	fgarc20x	Removed WFDS source
*********************************************************************************  
EXEC dbo.UspEtlProcessDataActualBoh  
    @Debug = 1  
  , @SourceApplicationName = 'OneMps'  
  , @YearWw = NULL --202047;  
  
  
*********************************************************************************/  
  
  
SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;  
  
SET NUMERIC_ROUNDABORT OFF;  
  
BEGIN TRY  
    -- Error and transaction handling setup ********************************************************  
    DECLARE  
        @ReturnErrorMessage VARCHAR(MAX)  
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)  
      , @CurrentAction      VARCHAR(4000)  
      , @DT                 VARCHAR(50)  = SYSDATETIME()  
      , @Message            VARCHAR(MAX);  
  
    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';  
  
    IF (@BatchId IS NULL)  
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
        @RowCount      INT  
  , @CurrentYearWw INT  
  , @DeleteCount INT = 0;  
  
  
 DECLARE @BohDeleted TABLE (ItemName VARCHAR(50) NULL, ActionName VARCHAR(50) NOT NULL);  
  
    ------------------------------------------------------------------------------------------------  
  
 EXEC dbo.UspEtlMergeTableLoadStatus  
        @Debug = @Debug  
      , @BatchRunId = @BatchRunId  
      , @SourceApplicationName = @SourceApplicationName  
      , @TableName = 'dbo.ActualBoh'  
   , @ProcessingStarted = 1  
      , @BatchId = @BatchId  
      , @ParameterList = @ParameterList;  
  
 SELECT @CurrentYearWw = c.YearWw  
 FROM dbo.Intelcalendar c  
 WHERE   
  SYSDATETIME() >= c.StartDate AND SYSDATETIME() < c.EndDate  
  
   
 SELECT @CurrentAction = 'Performing work';  
  
  
  
 MERGE dbo.ActualBoh t  
 USING (  
    SELECT ApplicationName ApplicationName  
      , b.ItemName, b.LocationName, b.SupplyCategory, b.YearWw, b.Boh, b.SourceAsOf  
    FROM dbo.StgActualBoh b  
    WHERE YearWw = @CurrentYearWw  
     AND ApplicationName  = @SourceApplicationName  
   )s  
   ON s.ItemName = t.ItemName AND s.LocationName = t.LocationName AND s.SupplyCategory = t.SupplyCategory AND s.YearWw = t.YearWw  
   AND t.SourceApplicationName = @SourceApplicationName  
 WHEN MATCHED AND s.Boh <> t.Boh THEN   
    UPDATE SET t.Boh = s.Boh, t.SourceAsOf = s.SourceAsOf, t.UpdatedOn = GETDATE(), t.UpdatedBy = ORIGINAL_LOGIN()  
 WHEN NOT MATCHED BY TARGET THEN   
   INSERT (SourceApplicationName, ItemName, LocationName, SupplyCategory, YearWw, Boh, SourceAsOf)  
   VALUES (s.ApplicationName, s.ItemName, s.LocationName, s.SupplyCategory, s.YearWw, s.Boh, s.SourceAsOf)  
 WHEN NOT MATCHED BY SOURCE AND t.YearWw = @CurrentYearWw AND t.SourceApplicationName = @SourceApplicationName THEN   
   DELETE  
 OUTPUT DELETED.ItemName, $action INTO @BohDeleted (ItemName, ActionName)  
 ;  
  
 SELECT @RowCount = COUNT(*) FROM @BohDeleted WHERE ActionName = 'DELETE';  
  
 EXEC dbo.UspEtlMergeTableLoadStatus  
        @Debug = @Debug  
      , @BatchRunId = @BatchRunId  
      , @SourceApplicationName = @SourceApplicationName  
      , @TableName = 'dbo.ActualBoh'  
      , @RowsPurged = @RowCount  
      , @BatchId = @BatchId  
      , @ParameterList = @ParameterList  
   , @ProcessingStarted = 0; -- Do not reset processing started.  
  
  
 SELECT @RowCount = COUNT(*) FROM @BohDeleted WHERE ActionName <> 'DELETE';  
  
    EXEC dbo.UspEtlMergeTableLoadStatus  
        @Debug = @Debug  
      , @BatchRunId = @BatchRunId  
      , @SourceApplicationName = @SourceApplicationName  
      , @TableName = 'dbo.ActualBoh'  
      , @RowsLoaded = @RowCount  
   , @ProcessingCompleted = 1  
      , @BatchId = @BatchId  
      , @ParameterList = @ParameterList;  
  
  
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
  
    -- re-throw the error  
    THROW;  
  
END CATCH;  
  
  