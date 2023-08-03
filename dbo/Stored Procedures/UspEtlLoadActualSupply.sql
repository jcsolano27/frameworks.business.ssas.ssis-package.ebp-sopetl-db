/*  
//--------------------------------------------------------------------------------------------------------------------------------------------//  
//Purpose  : Store Proc for Data Transformation for Statement of Supply  
//Author   : Arjun Sasikumar and Vipul Gugnani  
//Date     : 08/19/2020  
----    Date		User            Description    
----***********************************************************************************    
---- 2023-05-16		ldesousa		Adding Comments to Procedure  
----***********************************************************************************/  

CREATE PROC [dbo].[UspEtlLoadActualSupply]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50) = 'Denodo'
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = '*AdHoc*'
AS

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
        @RowCount      INT;

	DECLARE @MergeActions TABLE (ItemName VARCHAR(50) NULL);
    ------------------------------------------------------------------------------------------------
    
	/*
	EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.ActualSupply'
	  , @ProcessingStarted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;*/
	
	SELECT @CurrentAction = 'Performing work';

				
	WITH SupplyWW as (
		SELECT 
			A.*, 
			YearWw 
		FROM 
		[dbo].[StgActualSupply] A
		JOIN 
		[dbo].[IntelCalendar] C
			ON ScheduleDt BETWEEN StartDate and EndDate
			AND C.YearWw > 202253
			AND A.Quantity IS NOT NULL 
	),

	SupplyType as (
		SELECT 
			ApplicationName,
			ItemName,
			'IFG Test Out Actual' ScheduleTypeNm,
			YearWw,
			Quantity
		FROM SupplyWW
			WHERE ScheduleTypeNm = 'EXT AT POR'
				OR ScheduleTypeNm LIKE '%ATM POR%'
		UNION 
		SELECT 
			ApplicationName,
			ItemName,
			'IS POR' ScheduleTypeNm,
			YearWw,
			Quantity
		from SupplyWW
			WHERE ScheduleTypeNm IN 
			('SI POR', 'IS POR')
	)

	MERGE [dbo].[ActualSupply] as T
		USING 
			(
			SELECT
				ApplicationName,
				ItemName,
				ScheduleTypeNm,
				YearWw,
				SUM(Quantity) Quantity
			FROM SupplyType
			GROUP BY 
				ApplicationName,
				ItemName,
				ScheduleTypeNm,
				YearWw
		)

		AS S
			ON 	T.ItemName = S.ItemName
			AND T.ScheduleTypeNm = S.ScheduleTypeNm
			AND T.YearWw = S.YearWw
		WHEN NOT MATCHED BY Target THEN
			INSERT (SourceApplicationName,ItemName,ScheduleTypeNm, YearWw, Quantity)
			VALUES (S.ApplicationName, S.ItemName, S.ScheduleTypeNm, S.YearWw, S.Quantity)
		WHEN MATCHED THEN UPDATE SET
			T.Quantity = S.Quantity,
			T.[CreatedOn] = GETDATE(),
			T.[CreatedBy] = SESSION_USER
		OUTPUT	inserted.ItemName INTO @MergeActions (ItemName)
		;


	SELECT @RowCount = COUNT(*) FROM @MergeActions;
	/*
    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.ActualSupply'
      , @RowsLoaded = @RowCount
	  , @ProcessingCompleted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;
	  */

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