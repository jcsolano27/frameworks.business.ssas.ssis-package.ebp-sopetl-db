CREATE PROC [dbo].[EtlUpdateBatchRun]
    @Debug TINYINT = 0
	, @BatchRunStatus VARCHAR(100)
	, @BatchRunId INT = NULL
	, @BatchId VARCHAR(100) = NULL
	, @Exception VARCHAR(MAX) = NULL
AS
/*********************************************************************************
    Author:         Ben Sala
     
    Purpose:        Purges existing records to prepare for incoming data load. 

    Called by:      SSIS - MasterLoader.dtsx
         
    Result sets:    None
     
    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
    Date        User		    Description
***************************************************************************-
    2020-08-03  Ben Sala		Initial Release
    2020-09-28	Ben Sala		Added email upon failure. 
	2020-11-06	Ben Sala		Added application log for all failures.  Will only email on the first error now. 
	2021-03-02  Ben Sala        Added Abandoned logic to set batchrun's ahead of a failing one to be 
                                  abandoned instead of stuck in queued
*********************************************************************************
--EXEC etl.UspStartMpsLoad


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
	  , @Message			VARCHAR(MAX);

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
	DECLARE @BatchRunStatusId TINYINT 
		, @XML_BatchRun NVARCHAR(MAX)
		, @XML_TableLoadStatus NVARCHAR(MAX)
		, @EmailBody NVARCHAR(MAX)
		, @nl NVARCHAR(MAX) = CHAR(13) + CHAR(10)
		, @CurrentBatchStatus VARCHAR(20);
    ------------------------------------------------------------------------------------------------
	SELECT @CurrentAction = 'Validation';

	SELECT @BatchRunStatusId = s.BatchRunStatusId FROM dbo.EtlBatchRunStatus s WHERE s.StatusName = @BatchRunStatus;
	
	IF(@BatchRunStatusId IS NULL)
		RAISERROR('Invalid Status',16,1);


    -- Perform work ********************************************************************************
    SELECT @CurrentAction = 'Starting work';
	
	-- We only want to email one failure
	SELECT @CurrentBatchStatus = s.StatusName
	FROM dbo.EtlBatchRuns br
	INNER JOIN dbo.EtlBatchRunStatus s
		ON s.BatchRunStatusId = br.BatchRunStatusId
	WHERE br.BatchRunId = @BatchRunId;

	UPDATE br SET 
		br.BatchRunStatusId = @BatchRunStatusId
		, br.UpdatedOn = SYSDATETIME()
		, br.BatchStartedOn = 
			CASE 
				WHEN @BatchRunStatus = 'Processing' THEN SYSDATETIME()
				ELSE br.BatchStartedOn
			END
		, br.BatchCompletedOn = 
			CASE 
				WHEN @BatchRunStatus = 'Completed' THEN SYSDATETIME()
				ELSE br.BatchCompletedOn
			END
		, br.Exception = @Exception
	FROM dbo.EtlBatchRuns br
	WHERE
		br.BatchRunId = @BatchRunId;
	

	IF(@BatchRunStatus = 'ERROR')
	BEGIN
		EXEC dbo.UspAddApplicationLog
			  @LogSource = 'Database'
			, @LogType = 'ERROR'
			, @Category = 'Etl'
			, @SubCategory = @ErrorLoggedBy
			, @Message = @Exception
			, @Status = 'END'
			, @Exception = NULL
			, @BatchId = @BatchId;

		-- We only want to send the first failure email
		IF(@CurrentBatchStatus <> 'ERROR')
		BEGIN
			SELECT @Message = 'Prior failing BatchRun: ' + CAST(@BatchRunId AS VARCHAR(50)) + ' Prevented this batch from processing';

			UPDATE brque SET 
				brque.BatchRunStatusId = 6
				, brque.UpdatedOn = SYSDATETIME()
				, brque.UpdatedBy = ORIGINAL_LOGIN()
				, brque.Exception = @Message
			FROM dbo.EtlBatchRuns br
			INNER JOIN dbo.EtlBatchRuns brque
				ON brque.BatchRunId > br.BatchRunId
				AND brque.BatchRunStatusId = 2 -- Queued
			WHERE 
				br.BatchRunId = @BatchRunId
				
			SELECT @XML_BatchRun = ( 
				SELECT td = br.BatchRunId, ''
					, td = br.HostName, ''
					, td = a.SourceApplicationName, ''
					, td = br.ParameterList, ''
					, td = s.StatusName, ''
					, td = br.BatchStartedOn, ''
					, td = br.TableList, ''
					, td = br.CreatedOn, ''
					, td = br.UpdatedOn, ''
					, td = br.CreatedBy, ''
					, td = br.UpdatedBy, ''
					, td = br.Exception, ''
				FROM dbo.EtlBatchRuns br
				INNER JOIN dbo.EtlBatchRunStatus s
					ON s.BatchRunStatusId = br.BatchRunStatusId
				INNER JOIN dbo.EtlSourceApplications a
					ON a.SourceApplicationId = br.SourceApplicationId
				WHERE 
					br.BatchRunId = @BatchRunId
				FOR XML PATH('tr'), ELEMENTS
				);

			SELECT @XML_TableLoadStatus = (
				SELECT
					td = tls.TableId, ''
				  , td = t.TableName, ''
				  , td = tls.IsLoaded, ''
				  , td = tls.BatchRunId, ''
				  , td = ISNULL(CAST(tls.RowsLoaded AS VARCHAR(50)), ''), ''
				  , td = ISNULL(CAST(tls.RowsPurged AS VARCHAR(50)), ''), ''
				  , td = tls.CreatedOn, ''
				  , td = tls.CreatedBy, ''
				  , td = ISNULL(tls.UpdatedOn, ''), ''
				  , td = ISNULL(tls.UpdatedBy, ''), ''
				FROM dbo.EtlTableLoadStatus tls
				INNER JOIN dbo.EtlTables t
					ON t.TableId = tls.TableId
				WHERE
					tls.BatchRunId = @BatchRunId
					--OR (tls.IsLoaded = 0  AND EXISTS (SELECT 1 FROM dbo.EtlTables rt2 WHERE tls.TableId = rt2.TableId AND rt2.Active = 1))
				ORDER BY 
					  tls.IsLoaded
					, ISNULL(tls.UpdatedOn, tls.CreatedOn) DESC
				FOR XML PATH('tr'), ELEMENTS
				);

			IF(@Debug>=1)
				SELECT Len_BatchRun = DATALENGTH(@XML_BatchRun)
					, Len_TableStatus = DATALENGTH(@XML_TableLoadStatus)
					, BatchRun = @XML_BatchRun
					, TableStatus = @XML_TableLoadStatus;
	
			SELECT @EmailBody =	
				  '<html>' + @nl
				+ '  <body>'
				+ '    <H3>BatchRun details</H3>' + @nl
				+ '    <table border="1">' + @nl
				+ '    	 <tr>' + @nl
				+ '    	   <th>BatchRunId</th>' + @nl
				+ '    	   <th>HostName</th>' + @nl
				+ '    	   <th>SourceApplicationName</th>' + @nl
				+ '    	   <th>ParameterList</th>' + @nl
				+ '    	   <th>BatchStatus</th>' + @nl
				+ '    	   <th>BatchStartedOn</th>' + @nl
				+ '    	   <th>TableList</th>' + @nl
				+ '    	   <th>CreatedOn</th>' + @nl
				+ '    	   <th>UpdatedOn</th>' + @nl
				+ '    	   <th>CreatedBy</th>' + @nl
				+ '    	   <th>UpdatedBy</th>' + @nl
				+ '    	   <th>Exception</th>' + @nl
				+ '    	 </tr>' + @nl
				+ @XML_BatchRun
				+ '    </table>' + @nl + @nl
				+ '    <H3>Table Load Status</H3>' + @nl
				+ '    <table border="1">' + @nl
				+ '    	 <tr>' + @nl
				+ '    	   <th>TableId</th>' + @nl
				+ '    	   <th>TableName</th>' + @nl
				+ '    	   <th>IsLoaded</th>' + @nl
				+ '    	   <th>BatchRunId</th>' + @nl
				+ '    	   <th>RowsLoaded</th>' + @nl
				+ '    	   <th>RowsPurged</th>' + @nl
				+ '    	   <th>CreatedOn</th>' + @nl
				+ '    	   <th>CreatedBy</th>' + @nl
				+ '    	   <th>UpdatedOn</th>' + @nl
				+ '    	   <th>UpdatedBy</th>' + @nl
				+ '    	 </tr>' + @nl
				+ ISNULL(@XML_TableLoadStatus, '')
				+ '    </table>' + @nl + @nl
				+ '  </body>' + @nl
				+ '</html>' + @nl
				+ '<BR><BR>';

				IF(@Debug>=1)
					PRINT @EmailBody;

				EXEC dbo.UspMPSReconSendEmail
					@EmailBody = @EmailBody
				  , @EmailSubject = 'BatchRun Failure';
		END
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


