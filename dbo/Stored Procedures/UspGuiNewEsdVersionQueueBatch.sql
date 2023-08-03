



CREATE PROC [dbo].[UspGuiNewEsdVersionQueueBatch]
		@ReconMonthId INT
		,@EsdVersionName VARCHAR(50)
        ,@TableLoadGroupsList nVARCHAR(1000)  = null
		,@Debug TINYINT = 0
		,@BatchId VARCHAR(100) = NULL
		,@Bypass Int = 0
		,@NewEsdVersionId INT = NULL OUTPUT -- returns EsdVersionId created

AS
/*********************************************************************************
    Author:         Jeremy Webster
     
    Purpose:        Receive input from ESD Workbook - Manage ESD Versions UI and schedules ESD Batches to 
					Create a NEW ESD Version, then schedule 
					ESD Data Extract batches via etl.UspQueueBatchRun procedure

    Called by:      ESD Workbook - Manage ESD Versions UI - C# VSTO Workbook
         
    Result sets:    None
     
    Parameters:		@ReconMonthId int - MonthId of Recon Month for which the version will be created
					@EsdVersionName varchar(50) - Esd Version Name of new version to be created and queued
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
    2020-12-04	Jeremy Webster		Changed logic so that by default, all load groups except Bonusback are passed in on creation of new Esd Versions
	2021-06-10	Jeremy Webster		Added Bypass Logic for execution with user-defined Source Version Ids
*********************************************************************************/

	/*----------------------	TEST HARNESS   --------------------------------------
		EXEC [dbo].[UspGuiNewEsdVersionQueueBatch]  
			@PlanningMonthId = 216
		  , @EsdVersionName = 'Test Harness 14'
		  , @Debug = 0
		  , @Bypass = 1

		EXEC esd.UspCreateEsdVersion
	*/

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
		DECLARE @TableList VARCHAR(MAX) = NULL
			  , @EsdBaseVersionID   INT
			  , @Message			VARCHAR(MAX)
			  , @Iterator			INT
			  , @MaxIterator		INT
			  , @EsdVersionID		INT 
			  , @ReconMonth			INT
			  , @PriorMonth			INT
			  , @PriorMonthStartWw	INT


    ------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
    SELECT @CurrentAction = 'Starting work';

	----------For New ESD Versions, we will default to load all groups except Bonusback, the user cannot choose.
	DECLARE @DefaultCreationLoadGroups varchar(200)
		SELECT  @DefaultCreationLoadGroups = STUFF(
								(
									SELECT '|'+CAST(TableLoadGroupId as varchar) 
									FROM [dbo].[EtlTableLoadGroups]

									WHERE GroupType = 'ESD'
										AND TableLoadGroupName = 'MPS'
									For XML PATH('')
								),1,1,''
							)	

		-- Create new ESD Base Version and ESD Version as needed
		IF NOT EXISTS (
							SELECT * FROM dbo.[EsdVersions] T1 
							JOIN dbo.EsdBaseVersions T2
								ON T1.EsdBaseVersionId = T2.EsdBaseVersionId
							WHERE T1.EsdVersionName  = @EsdVersionName
							AND		T2.PlanningMonthId = @ReconMonthId
						)
			BEGIN
				EXECUTE dbo.[UspGuiEsdCreateEsdVersion]
					  @EsdVersionName = @EsdVersionName
					, @PlanningMonthId= @ReconMonthId
					, @Bypass = @Bypass
					, @NewEsdVersionId = @EsdVersionID OUTPUT
			END
		ELSE
			BEGIN
				RAISERROR('An Esd Version Already exists with the name specified for this month. Insure a unique name is given.',16,1);
			END

		SELECT @EsdVersionID as EsdVersionId

		IF(@Debug >= 1)
			SELECT @EsdVersionID AS NewEsdVersionId, @DefaultCreationLoadGroups AS DefaultCreationLoadGroups

		BEGIN							--Pass all but Bonusback
			EXECUTE dbo.UspGuiEsdQueueBatch 
				@EsdVersionID=@EsdVersionID
				,@Debug=1
				,@TableLoadGroupsList=@DefaultCreationLoadGroups
		END

		SELECT @NewEsdVersionId = @EsdVersionID;

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







