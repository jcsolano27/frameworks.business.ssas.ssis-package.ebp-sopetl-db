----*********************************************************************************
----    Purpose:	Loading actual billings data. 
----				The procedure is supposed to be called weekly on Sundays.

----    Date        User            Description
----*********************************************************************************
----    2023-03-17	caiosanx        Initial Release
----*********************************************************************************

CREATE   PROC [dbo].[UspEtlLoadActualBillings]
    @Debug TINYINT = 0,
    @BatchId VARCHAR(100) = NULL,
    @SourceApplicationName VARCHAR(50) = 'Denodo',
    @BatchRunId INT = -1,
    @ParameterList VARCHAR(1000) = '*AdHoc*'
AS

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- ERROR HANDLING PREPARATION
    DECLARE @ReturnErrorMessage VARCHAR(MAX),
            @ErrorLoggedBy VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),
            @CurrentAction VARCHAR(4000),
            @DT VARCHAR(50) = SYSDATETIME(),
            @Message VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

    IF (@BatchId IS NULL)
        SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

    EXEC dbo.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Info',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @Message,
                                  @Status = 'BEGIN',
                                  @Exception = NULL,
                                  @BatchId = @BatchId;

    -- DECLARING AND SETTING VALUES TO VARIABLES
    DECLARE @RowCount INT;
    DECLARE @MergeActions TABLE (ItemName VARCHAR(50) NULL);
    DECLARE @InputTable AS udtt_PcDistributionIn;
    DECLARE @LastUpdateSystemDtm DATETIME = (SELECT MAX(LastUpdateSystemDtm) FROM dbo.StgActualBillings);
	DECLARE @CurrentDate DATETIME = GETDATE();
    DECLARE @CurrYearQq INT = (SELECT YearQq FROM dbo.IntelCalendar WHERE @CurrentDate BETWEEN StartDate AND DATEADD(MILLISECOND, -3, EndDate));
    DECLARE @CurrentYearWw INT = (SELECT YearWw FROM dbo.IntelCalendar WHERE @CurrentDate BETWEEN StartDate AND DATEADD(MILLISECOND, -3, EndDate));
	DECLARE @PreviousYearQq INT = (SELECT X.PreviousYearQq FROM(SELECT YearQq, LAG(YearQq) OVER (ORDER BY YearQq) PreviousYearQq FROM dbo.IntelCalendar GROUP BY YearQq) X WHERE X.YearQq = @CurrYearQq);
    DECLARE @MinStartDate DATETIME = (SELECT MIN(StartDate)FROM dbo.IntelCalendar WHERE YearQq = @CurrYearQq );
    DECLARE @MinYearWw INT = (SELECT MIN(YearWw) FROM dbo.IntelCalendar WHERE YearQq = CASE WHEN CAST(@MinStartDate AS DATE) = CAST(@CurrentDate AS DATE) THEN @PreviousYearQq ELSE @CurrYearQq END);
    DECLARE @TargetWw TABLE (YearWw INT);
	INSERT  @TargetWw SELECT DISTINCT YearWwNbr FROM dbo.StgActualBillings WHERE YearWwNbr >= @MinYearWw;
	SET     @CurrentAction = 'Performing work';

    ---- MERGE ACTUALBILLINGS DATA  ---- 
    MERGE [dbo].[ActualBillings] AS T
	USING
	(
		SELECT @SourceApplicationName AS SourceApplicationName,
			   H.FinishedGoodItemId ItemName,
			   B.YearWwNbr AS YearWw,
			   P.ProfitCenterCd,
			   SUM(CAST(B.CGIDNetBomQty AS FLOAT)) AS Quantity,
			   B.LastUpdateSystemDtm
		FROM dbo.StgActualBillings AS B
			JOIN [dbo].[StgProductHierarchy] AS H
				ON B.ProductNodeID = H.ProductNodeID
				   AND ISNULL(H.SpecCd, 0) <> 'Q'
			JOIN [dbo].[StgProfitCenterHierarchy] AS P
				ON P.ProfitCenterHierarchyId = B.ProfitCenterHierarchyId
		WHERE H.FinishedGoodItemId IS NOT NULL
			  AND B.YearWwNbr >= @MinYearWw
			  AND B.YearWwNbr < @CurrentYearWw -- GET DATA FROM THE START OF CURRENT QUARTER TO THE CURRENT WEEK-1 --IF IT'S THE FIRST DAY OF THE QUARTER, THE PREVIOUS ONE WILL BE LOADED
		GROUP BY H.FinishedGoodItemId,
				 B.YearWwNbr,
				 P.ProfitCenterCd,
				 B.LastUpdateSystemDtm
	) AS S
	ON T.ItemName = S.ItemName
	   AND T.YearWw = S.YearWw
	   AND T.SourceApplicationName = S.SourceApplicationName
	   AND T.ProfitCenterCd = S.ProfitCenterCd
	WHEN NOT MATCHED BY TARGET THEN
		INSERT
		(
			SourceApplicationName,
			ItemName,
			YearWw,
			ProfitCenterCd,
			Quantity
		)
		VALUES
		(S.SourceApplicationName, S.ItemName, S.YearWw, S.ProfitCenterCd, S.Quantity)
	WHEN MATCHED AND ROUND(COALESCE(T.[Quantity], 0), 3) <> ROUND(COALESCE(S.Quantity, 0), 3) THEN
		UPDATE SET T.Quantity = S.Quantity,
				   T.ModifiedOn = S.LastUpdateSystemDtm,
				   T.ModifiedBy = SESSION_USER
	WHEN NOT MATCHED BY SOURCE AND T.YearWw IN
								   (
									   SELECT YearWw FROM @TargetWw
								   ) THEN
		DELETE;

-- SETTING @RowCount VALUE
	SELECT @RowCount = COUNT(*) FROM [dbo].[ActualBillings] WHERE ModifiedOn = @LastUpdateSystemDtm;
END TRY

-- ERROR HANDLING
BEGIN CATCH
    SELECT @ReturnErrorMessage
        = 'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
          + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
          + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
          + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');

    EXEC dbo.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Error',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @CurrentAction,
                                  @Status = 'ERROR',
                                  @Exception = @ReturnErrorMessage,
                                  @BatchId = @BatchId;
    THROW;
END CATCH;	