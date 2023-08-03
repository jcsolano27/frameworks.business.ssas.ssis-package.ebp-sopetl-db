
CREATE   PROC [dbo].[UspLoadHdmrSnapshot]
AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from Hdmr Sources to Target Supply table (WIP)
*************************************************************************************/

BEGIN

----/*********************************************************************************
     
----    Purpose: This proc is used to load data from Hdmr Sources to Target Supply table (WIP)
----    Sources: [dbo].[StgHdmrSnapshot]
----    Destinations: [dbo].HdmrSnapshot

----    Called by:      SSIS
         
----    Result sets:    None
     
----    Parameters: None
         
----    Return Codes:   0 = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-06-27  hmanentx        Initial Release

----*********************************************************************************/
	
	SET NOCOUNT ON

    BEGIN TRY

		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
		  , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		  , @CurrentAction      VARCHAR(4000)
		  , @DT                 VARCHAR(50)  = SYSDATETIME()
		  , @Message            VARCHAR(MAX)
		  , @BatchId			VARCHAR(512)

		SET @CurrentAction = @ErrorLoggedBy + ': SP Starting'

		SET @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN()

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Info'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @Message
		  , @Status = 'BEGIN'
		  , @Exception = NULL
		  , @BatchId = @BatchId;

	/*
	EXEC [dbo].[UspLoadHdmrSnapshot]
	*/

	------> Create Variables
		DECLARE	@CONST_ParameterId_TargetSupply		INT = [dbo].[CONST_ParameterId_TargetSupply]()

	------> Create Table Variables
		DECLARE @HdmrSnapshot TABLE (

			SourceVersionId		INT PRIMARY KEY
		,	PlanningMonth		INT NOT NULL
		,	SourceVersionNm		VARCHAR(MAX)
		,	HdmrVersionNm		VARCHAR(MAX)
		,	SnapshotType		VARCHAR(50)
		)

	------> HdmrSnapshot

		-- The distinct was used because we may have lines with the same data with only different ProcessStatus. All other values are the same and we had some duplicated key issues.
	
		;WITH CTE_StgHdmrSnapshot_LastPublishTs AS
		(
			SELECT
				SnapshotId
				,MAX(PublishTs) AS PublishTs
			FROM [dbo].[StgHdmrSnapshot]
			GROUP BY SnapshotId
		)
		INSERT INTO @HdmrSnapshot
		SELECT
			Hdmr.SnapshotId AS SourceVersionId
		,	CAST(REPLACE(Hdmr.PlanningCycle,'M','') AS INT) AS PlanningMonth
		,	Hdmr.SnapshotNm AS SourceVersionNm
		,	Hdmr.HdmrVersionNm
		,	Hdmr.SnapshotType
		FROM [dbo].[StgHdmrSnapshot] Hdmr
			INNER JOIN [dbo].PlanningMonths PM 
				ON PM.PlanningMonth = CAST(REPLACE(Hdmr.PlanningCycle,'M','') AS INT)
			INNER JOIN CTE_StgHdmrSnapshot_LastPublishTs C
				ON C.SnapshotId = Hdmr.SnapshotId
				AND C.PublishTs = Hdmr.PublishTs

	------> Final Load
		MERGE
		[dbo].HdmrSnapshot AS Hdmr --Destination Table
		USING 
		@HdmrSnapshot AS HS --Source Table
			ON 		(Hdmr.SourceVersionId	= HS.SourceVersionId)
		WHEN MATCHED and (		Hdmr.PlanningMonth		<> HS.PlanningMonth	
							OR	Hdmr.SourceVersionNm	<> HS.SourceVersionNm
							OR	Hdmr.HdmrVersionNm		<> HS.HdmrVersionNm	
							OR	Hdmr.SnapshotType		<> HS.SnapshotType
						 )		
			THEN
				UPDATE SET		
							Hdmr.PlanningMonth		= HS.PlanningMonth	
						,	Hdmr.SourceVersionNm	= HS.SourceVersionNm
						,	Hdmr.HdmrVersionNm		= HS.HdmrVersionNm	
						,	Hdmr.SnapshotType		= HS.SnapshotType	
						,	Hdmr.CreatedOn			= GETDATE()
						,	Hdmr.CreatedBy			= ORIGINAL_LOGIN()

		WHEN NOT MATCHED
			THEN
				INSERT
				VALUES (HS.SourceVersionId,HS.PlanningMonth ,HS.SourceVersionNm ,HS.HdmrVersionNm ,HS.SnapshotType,getdate(),original_login());

		SET NOCOUNT OFF

		-- Log Handling ********************************************************
		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Info'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @Message
		  , @Status = 'END'
		  , @Exception = NULL
		  , @BatchId = @BatchId;

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

		 --re-throw the error
		THROW;

	END CATCH

END