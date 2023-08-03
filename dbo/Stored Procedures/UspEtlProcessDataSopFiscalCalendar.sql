
CREATE     PROC [dbo].[UspEtlProcessDataSopFiscalCalendar]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = ''

AS
----/*********************************************************************************
     
----    Purpose:        Processes data   
----                        Source:      [dbo].[StgEsdBonusableSupply]
----                        Destination: [dbo].[EsdBonusableSupply] / [dbo].[EsdBonusableSupplyExceptions]

----    Called by:      SSMS
         
----    Result sets:    None
     
----    Parameters:
----                    @Debug:
----                        1 - Will output some basic info with timestamps
----                        2 - Will output everything from 1, as well as rowcounts
         
----    Return Codes:   0   = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2022-09-23  hmanentx        Initial Release

----*********************************************************************************/

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

	-- Main Logic

		-- Remove Duplicates From Stage
		DROP TABLE IF EXISTS #DataStgSopFiscalCalendar
		
		SELECT
			[SourceApplicationName]
			,[SourceVersionId]
			,[Fiscal Calendar Identifier]
			,[Start Date]
			,[LastMonthOfFiscalQuarterNbr]
			,[FiscalQuarterNbr]
			,[FiscalQuarterWorkweekNbr]
			,[RelativeFiscalMonthsFromTodayNbr]
			,[RelativeQuarter]
			,[RelativeWorkweek]
			,[RelativeYear]
			,[WorkWeekNm]
			,[WorkWeekNbr]
			,[FiscalAbbreviatedMonthYearNm]
			,[FiscalMonthNm]
			,[FiscalMonthNbr]
			,[Year]
			,[Fiscal Year Quarter Name]
			,[FiscalYearQuarterNbr]
			,[Workweek]
			,[WeeksInFiscalMonthCnt]
			,[WeeksInFiscalQuarterCnt]
			,[FiscalPeriodEndDateTxt]
			,[RelativeDaysFromTodayNbr]
			,[FiscalMonthWorkweekNbr]
			,[FiscalQuarterMonthNbr]
			,[CalendarCharDt]
			,[FiscalYearMonthNm]
			,[FiscalYearMonthNbr]
			,[SourceNm]
			,[LastYearMonthOfFiscalQuarterNbr]
			,[CreatedOn]
			,[CreatedBy]
			,ROW_NUMBER() OVER (PARTITION BY [Fiscal Calendar Identifier], [Start Date] ORDER BY [Fiscal Calendar Identifier]) AS RowId
		INTO #DataStgSopFiscalCalendar
		FROM [dbo].[StgSopFiscalCalendar]

		-- Remove Duplicates
		DELETE FROM #DataStgSopFiscalCalendar
		WHERE RowId > 1

		-- Merge Entries to the Main Table
		MERGE [dbo].[SopFiscalCalendar] AS S
		USING #DataStgSopFiscalCalendar AS Stg
		ON (Stg.[Fiscal Calendar Identifier] = S.[FiscalCalendarIdentifier]
			AND Stg.[Start Date] = S.[StartDate])
		WHEN MATCHED THEN
		UPDATE SET
			S.[SourceApplicationName] = Stg.[SourceApplicationName]
			,S.[SourceVersionId] = Stg.[SourceVersionId]
			,S.[StartDate] = Stg.[Start Date]
			,S.[LastMonthOfFiscalQuarterNbr] = Stg.[LastMonthOfFiscalQuarterNbr]
			,S.[FiscalQuarterNbr] = Stg.[FiscalQuarterNbr]
			,S.[FiscalQuarterWorkweekNbr] = Stg.[FiscalQuarterWorkweekNbr]
			,S.[RelativeFiscalMonthsFromTodayNbr] = Stg.[RelativeFiscalMonthsFromTodayNbr]
			,S.[RelativeQuarter] = Stg.[RelativeQuarter]
			,S.[RelativeWorkweek] = Stg.[RelativeWorkweek]
			,S.[RelativeYear] = Stg.[RelativeYear]
			,S.[WorkWeekNm] = Stg.[WorkWeekNm]
			,S.[WorkWeekNbr] = Stg.[WorkWeekNbr]
			,S.[FiscalAbbreviatedMonthYearNm] = Stg.[FiscalAbbreviatedMonthYearNm]
			,S.[FiscalMonthNm] = Stg.[FiscalMonthNm]
			,S.[FiscalMonthNbr] = Stg.[FiscalMonthNbr]
			,S.[YearNbr] = Stg.[Year]
			,S.[FiscalYearQuarterName] = Stg.[Fiscal Year Quarter Name]
			,S.[FiscalYearQuarterNbr] = Stg.[FiscalYearQuarterNbr]
			,S.[Workweek] = Stg.[Workweek]
			,S.[WeeksInFiscalMonthCnt] = Stg.[WeeksInFiscalMonthCnt]
			,S.[WeeksInFiscalQuarterCnt] = Stg.[WeeksInFiscalQuarterCnt]
			,S.[FiscalPeriodEndDateTxt] = Stg.[FiscalPeriodEndDateTxt]
			,S.[RelativeDaysFromTodayNbr] = Stg.[RelativeDaysFromTodayNbr]
			,S.[FiscalMonthWorkweekNbr] = Stg.[FiscalMonthWorkweekNbr]
			,S.[FiscalQuarterMonthNbr] = Stg.[FiscalQuarterMonthNbr]
			,S.[CalendarCharDt] = Stg.[CalendarCharDt]
			,S.[FiscalYearMonthNm] = Stg.[FiscalYearMonthNm]
			,S.[FiscalYearMonthNbr] = Stg.[FiscalYearMonthNbr]
			,S.[SourceNm] = Stg.[SourceNm]
			,S.[LastYearMonthOfFiscalQuarterNbr] = Stg.[LastYearMonthOfFiscalQuarterNbr]
			,S.[ModifiedOn] = Stg.CreatedOn
			,S.[UpdatedBy] = Stg.CreatedBy
		WHEN NOT MATCHED BY TARGET THEN
			INSERT
			(
				SourceApplicationName
				,SourceVersionId
				,FiscalCalendarIdentifier
				,StartDate
				,LastMonthOfFiscalQuarterNbr
				,FiscalQuarterNbr
				,FiscalQuarterWorkweekNbr
				,RelativeFiscalMonthsFromTodayNbr
				,RelativeQuarter
				,RelativeWorkweek
				,RelativeYear
				,WorkWeekNm
				,WorkWeekNbr
				,FiscalAbbreviatedMonthYearNm
				,FiscalMonthNm
				,FiscalMonthNbr
				,YearNbr
				,FiscalYearQuarterName
				,FiscalYearQuarterNbr
				,Workweek
				,WeeksInFiscalMonthCnt
				,WeeksInFiscalQuarterCnt
				,FiscalPeriodEndDateTxt
				,RelativeDaysFromTodayNbr
				,FiscalMonthWorkweekNbr
				,FiscalQuarterMonthNbr
				,CalendarCharDt
				,FiscalYearMonthNm
				,FiscalYearMonthNbr
				,SourceNm
				,LastYearMonthOfFiscalQuarterNbr
				,ModifiedOn
				,UpdatedBy

			)
			VALUES
			(
				Stg.[SourceApplicationName]
				,Stg.[SourceVersionId]
				,Stg.[Fiscal Calendar Identifier]
				,Stg.[Start Date]
				,Stg.[LastMonthOfFiscalQuarterNbr]
				,Stg.[FiscalQuarterNbr]
				,Stg.[FiscalQuarterWorkweekNbr]
				,Stg.[RelativeFiscalMonthsFromTodayNbr]
				,Stg.[RelativeQuarter]
				,Stg.[RelativeWorkweek]
				,Stg.[RelativeYear]
				,Stg.[WorkWeekNm]
				,Stg.[WorkWeekNbr]
				,Stg.[FiscalAbbreviatedMonthYearNm]
				,Stg.[FiscalMonthNm]
				,Stg.[FiscalMonthNbr]
				,Stg.[Year]
				,Stg.[Fiscal Year Quarter Name]
				,Stg.[FiscalYearQuarterNbr]
				,Stg.[Workweek]
				,Stg.[WeeksInFiscalMonthCnt]
				,Stg.[WeeksInFiscalQuarterCnt]
				,Stg.[FiscalPeriodEndDateTxt]
				,Stg.[RelativeDaysFromTodayNbr]
				,Stg.[FiscalMonthWorkweekNbr]
				,Stg.[FiscalQuarterMonthNbr]
				,Stg.[CalendarCharDt]
				,Stg.[FiscalYearMonthNm]
				,Stg.[FiscalYearMonthNbr]
				,Stg.[SourceNm]
				,Stg.[LastYearMonthOfFiscalQuarterNbr]
				,Stg.[CreatedOn]
				,Stg.[CreatedBy]
			);
			
	-- End Main Logic
    
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

     --re-throw the error
    THROW;

END CATCH;