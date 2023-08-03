
CREATE   PROC [dbo].[UspLoadSnOPCompassMRPFabRoutingAPI]
    @PublishLogId INT = 0
  , @NumberOfQuarters INT = 6

AS
----/*********************************************************************************
     
----    Purpose:        Processes data   
----                        Source:      [dbo].[v_SnOPCompassMRPFabRouting]
----                        Destination: Denodo Web Service - CompassMRPFabRouting

----    Called by:      Denodo Web Service - CompassMRPFabRouting
         
----    Result sets:    None
     
----    Parameters:
----                    
----                    @PublishLogId - PublishLogId to be returned by the query. If none is passed in the parameters the latest PublishLogId is returned. 
----                    @NumberOfQuarters - NumberOfQuarters to be returned by the query. If none is passed in the parameters the first 6 quarters are returned.   
----                        
         
----    Return Codes:   0   = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-04-18  rmiralhx        Initial Release
----*********************************************************************************/

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY

----* Error and transaction handling setup ********************************************************
    DECLARE
		@BatchId VARCHAR(100) = NULL
      , @ReturnErrorMessage VARCHAR(MAX)
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

	DECLARE 
		@curr_YearQuarter INT = 0 
		,@curr_PublishLogId INT = 0
		,@min_RelativeQuarter INT
		,@curr_year INT
		,@relativeQuarter INT = 0;


	SELECT @curr_PublishLogId = MAX(PublishLogId) FROM [dbo].[v_SnOPCompassMRPFabRoutingHist];
	SELECT @curr_YearQuarter = CONCAT(CAST(DATEPART(year,GETDATE()) AS VARCHAR),RIGHT('0'+CAST(DATEPART(quarter,GETDATE()) AS VARCHAR),2));
	SELECT @curr_Year = DATEPART(year,GETDATE());
	SELECT @min_RelativeQuarter = MIN(RelativeQuarter) FROM [dbo].[SopFiscalCalendar] WHERE FiscalYearQuarterNbr = @curr_YearQuarter;	
	SELECT @curr_PublishLogId = MAX(PublishLogId) FROM [dbo].[SnOPCompassMRPFabRouting];
	SELECT @relativeQuarter = @min_RelativeQuarter

 --Check values and adjust variables to return expected quarter/PublishLogIds
	SELECT @PublishLogId = CASE WHEN @PublishLogId IS NULL OR @PublishLogId = 0 THEN @curr_PublishLogId ELSE @PublishLogId END 
	SELECT @NumberOfQuarters = CASE WHEN @NumberOfQuarters IS NULL OR @NumberOfQuarters= 6 THEN @relativeQuarter+5 WHEN @NumberOfQuarters = 7 THEN @relativeQuarter+6 ELSE @relativeQuarter+5 END
	
	--Return the latest PublishLogId and number of quarters specified
	BEGIN
	IF (@PublishLogId = 0)
		BEGIN
		SELECT H.[PublishLogId]
			,H.[SourceItem]
			,H.[ItemName]
			,H.[LocationName]
			,H.[ParameterTypeName]
			,H.[Quantity] 
			,H.[BucketType]
			,H.[FiscalYearWorkWeekNbr]
			,H.[FabProcess]
			,H.[DotProcess]
			,H.[LrpDieNm]
			,OverrideTechNode AS [TechNode]
		FROM [dbo].[v_SnOPCompassMRPFabRoutingHist] H
		INNER JOIN (	
					SELECT Process,OverrideTechNode
					FROM [dbo].[RefSnOPCompassMRPFabRoutingProcessMapping]
					WHERE IsVisibleDownstream = 1
				) tech ON tech.Process = H.FabProcess
		INNER JOIN  [dbo].[SopFiscalCalendar] S ON S.FiscalCalendarIdentifier = H.FiscalYearWorkWeekNbr
			AND H.PublishLogId = @PublishLogId
			AND S.FiscalYearQuarterNbr >= @curr_YearQuarter
			AND RelativeQuarter <=  @NumberOfQuarters
		INNER JOIN (
				SELECT LocationName
				FROM [dbo].[RefSnOPCompassMRPFabRoutingLocation]
				WHERE IsVisibleDownstream = 1	
				) loc ON TRIM(LOWER(loc.LocationName)) = TRIM(LOWER(H.[LocationName]));
		RETURN;
		END 
	END

	--Return the PublishLogId and number of quarters specified
	BEGIN
	IF (@PublishLogId <> 0)
		BEGIN 
				SELECT H.[PublishLogId]
			,H.[SourceItem]
			,H.[ItemName]
			,H.[LocationName]
			,H.[ParameterTypeName]
			,H.[Quantity] 
			,H.[BucketType]
			,H.[FiscalYearWorkWeekNbr]
			,H.[FabProcess]
			,H.[DotProcess]
			,H.[LrpDieNm]
			,OverrideTechNode AS [TechNode]
		FROM [dbo].[v_SnOPCompassMRPFabRoutingHist] H
		INNER JOIN (	
					SELECT Process,OverrideTechNode
					FROM [dbo].[RefSnOPCompassMRPFabRoutingProcessMapping]
					WHERE IsVisibleDownstream = 1
				) tech ON tech.Process = H.FabProcess
		INNER JOIN  [dbo].[SopFiscalCalendar] S ON S.FiscalCalendarIdentifier = H.FiscalYearWorkWeekNbr
			AND H.PublishLogId = @PublishLogId
			AND S.FiscalYearQuarterNbr >= @curr_YearQuarter
			AND RelativeQuarter <=  @NumberOfQuarters
		INNER JOIN (
				SELECT LocationName
				FROM [dbo].[RefSnOPCompassMRPFabRoutingLocation]
				WHERE IsVisibleDownstream = 1	
				) loc ON TRIM(LOWER(loc.LocationName)) = TRIM(LOWER(H.[LocationName]));
		RETURN;
		END 
	END
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

-- COMMIT
-- ROLLBACK
-- DROP TABLE IF EXISTS [dbo].[SvdOutput_bkp20230601]; 