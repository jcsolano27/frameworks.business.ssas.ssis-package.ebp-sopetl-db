CREATE PROC [dbo].[UspSvdBeginBatchRun_ANA]

--EXEC [dbo].[UspSvdBeginBatchRun_ANA]

AS
/*********************************************************************************
    Author:         
         
    Result sets:    None
     
    Parameters:
                    @Debug:
                        1 - Will output some basic info with timestamps
                        2 - Will output everything from 1, as well as rowcounts
         
    Return Codes:   0   = Success
					1	= No work to do
                    < 0 = Error
                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
    Exceptions:     None expected
     
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
	  , @Message			VARCHAR(MAX)
	  --, @Debug				TINYINT = 0
	  , @BatchId			VARCHAR(100)

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';
	SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN(); -- BATCH ID = 
	
	
	EXEC dbo.UspAddApplicationLog -- send a begin log into the app
		  @LogSource = 'Database'
		, @LogType = 'Info'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @Message
		, @Status = 'BEGIN'
		, @Exception = NULL
		, @BatchId = @BatchId;


    -- Parameters and temp tables used by this sp **************************************************
	DECLARE @BatchRuns TABLE (BatchRunId INT IDENTITY (1,1)
								,BatchId VARCHAR(1000)
								,SourceApplicationName VARCHAR(10)
								,TableList VARCHAR(MAX)
								,LoadParameters  VARCHAR(100)
								,ParameterList  VARCHAR(1000)); -- TEMP BATCH RUN TABLE
    ------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
    --SELECT @CurrentAction = 'Starting work';
	   
		--Concatenate versions/sources to update in one column
		WITH tmp_Version AS (
		SELECT SS.LoadSourceNm, SS.SvdSourceApplicationId,
		   STUFF((SELECT ',' + CONVERT(VARCHAR, US.VersionId)
				  FROM [dbo].[StgSvdLoadStatus_ANA] US
				  WHERE US.LoadSourceNm = SS.LoadSourceNm
				  FOR XML PATH('')), 1, 1, '') AS VersionsId
		FROM [dbo].[StgSvdLoadStatus_ANA] SS
		GROUP BY SS.LoadSourceNm, SS.SvdSourceApplicationId
		)



		
		--Update LoadSatus with Hana/Denodo sources
		UPDATE [dbo].[SvdLoadStatus_ANA] 
		   SET VersionsId = tb2.VersionsId 
				,SvdSourceApplicationId = tb2.SvdSourceApplicationId
				,IsLoad=1
		   FROM [dbo].[SvdLoadStatus_ANA] tb1  
				INNER JOIN tmp_Version tb2 ON tb1.SourceNm = tb2.LoadSourceNm
		   WHERE tb1.SvdSourceApplicationId IN (5,6) --Denodo

		   --Update LoadSatus with Profisee sources
		   UPDATE [dbo].[SvdLoadStatus_ANA] 
		   SET LastLoadDate = tb2.LastModifiedDate
				,SvdSourceApplicationId = tb2.SvdSourceApplicationId
				,IsLoad = CASE WHEN tb2.LastModifiedDate > tb1.LastModifiedDate THEN 1 ELSE 0 END
		   FROM [dbo].[SvdLoadStatus_ANA] tb1  
				INNER JOIN [dbo].[StgSvdLoadStatus_ANA] tb2 ON tb1.SourceNm = tb2.LoadSourceNm
		   WHERE tb1.SvdSourceApplicationId=1 --Profisee

		INSERT INTO @BatchRuns
			SELECT
			 @BatchId AS BatchId
			, sa.SvdSourceApplicationName AS SourceApplicationName 
			, br.PackageNm AS TableList
			, 'Datetime' AS LoadParameters
			, 'Datetime=20008234' AS ParameterList
		FROM (
			SELECT SS.SvdSourceApplicationId, SS.VersionType,
			   STUFF((SELECT DISTINCT '|' + US.PackageNm
					  FROM [dbo].[SvdLoadStatus_ANA]  US
					  WHERE US.SvdSourceApplicationId = SS.SvdSourceApplicationId
					  AND (US.IsLoad=1 OR US.IsForceLoad=1)
					  FOR XML PATH('')), 1, 1, '') AS PackageNm
			FROM [dbo].[SvdLoadStatus_ANA] SS
			WHERE (SS.IsLoad=1 OR SS.IsForceLoad=1)
			GROUP BY SS.SvdSourceApplicationId, SS.VersionType
		) br
		INNER JOIN dbo.SvdSourceApplications sa
			ON sa.SvdSourceApplicationId = br.SvdSourceApplicationId

	SELECT * FROM @BatchRuns

	EXEC dbo.UspAddApplicationLog -- LOGGED END INTO USPADDAPPLICATIONLOG AS INFO
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
BEGIN CATCH -- IN CASE SOMETHING FAILED IT'S LOGGED INTO USPADDAPPLICATIONLOG AS ERROR
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


