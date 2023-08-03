-- =============================================
-- Author:		Juan Carlos Solano 
-- Create date:	July 20, 2022
-- Description:	This procedure will return the minimun Timedate on a list of tables
-- =============================================

CREATE PROCEDURE [dbo].[UspETLFetchMinimunTimeDate]
	@TableList VARCHAR(MAX)
	,@BatchId VARCHAR(100) = NULL
	,@Datetime VARCHAR(1000) OUTPUT
AS
BEGIN

	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

	SET NUMERIC_ROUNDABORT OFF;

	BEGIN TRY
		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
		  , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		  , @CurrentAction      VARCHAR(4000)
		  , @CurrentDT                 VARCHAR(50) = SYSDATETIME();

		SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

		IF(@BatchId IS NULL) 
			SELECT @BatchId = @ErrorLoggedBy + '.' + @CurrentDT + '.' + ORIGINAL_LOGIN();
	
		EXEC dbo.UspAddApplicationLog
			  @LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = @ErrorLoggedBy
			, @SubCategory = @ErrorLoggedBy
			, @Message = @CurrentAction
			, @Status = 'BEGIN'
			, @Exception = NULL
			, @BatchId = @BatchId;

		DECLARE @MAXID INT;
		DECLARE @TableName VARCHAR(1000);
		DECLARE @ID INT = 1;
		DECLARE @DT VARCHAR(1000);

		CREATE TABLE #TablesDT
		(
			Id INT IDENTITY(1, 1),
			TableName VARCHAR(MAX)
		);

		INSERT INTO #TablesDT
		SELECT * FROM STRING_SPLIT(@TABLELIST, '|');
		SELECT @MAXID = MAX(ID) FROM #TablesDT;

		WHILE @ID <= @MAXID
		BEGIN 
			SELECT @TableName = TableName FROM #TablesDT WHERE ID = @ID;
			DECLARE @QUERY NVARCHAR(1000) = 'SELECT @DT=CONVERT(VARCHAR(100),MAX(ModifiedOn),120) FROM ' + @TableName;
			EXEC sp_executesql @Query=@QUERY
			, @Params = N'@DT VARCHAR(100) OUTPUT'
			, @DT = @DT OUTPUT
			;
			SELECT @Datetime = CASE WHEN (@DT < @Datetime) OR (@Datetime IS NULL) THEN @DT ELSE @Datetime END;
			SET @ID +=1
		END 
		DROP TABLE #TablesDT;
		SELECT @Datetime = ISNULL(@Datetime,'2018-01-01 00:00:00')
		RETURN;
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
END

