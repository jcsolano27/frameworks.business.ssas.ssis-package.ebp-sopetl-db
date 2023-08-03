/*
//&---------------------------------------------------------------------//
//Purpose  : Summarize ESD Supply from MM to SnOPDemandProduct
//Author   : Steve Liu
//Date     : 05/26/2022

//Versions : 

// Version    Date            Modified by           Reason
// =======    ====            ===========           ======
//&---------------------------------------------------------------------// */

CREATE PROCEDURE [dbo].[UspLoadEsdSupplyByDpWeek]
	@EsdVersionId int
	,@Debug TINYINT = 0
	,@BatchId VARCHAR(100) = NULL
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


	/* Test Harness
		exec  [dbo].[UspLoadEsdSupplyByDpWeek] @EsdVersionId = 155
	*/

	------------------------------------------------------------------------------------------------
    -- Perform work ********************************************************************************
	--DECLARE @EsdVersionId int =17
	DELETE FROM dbo.EsdSupplyByDpWeek WHERE EsdVersionId = @EsdVersionId

	DECLARE @LastStitchYearWw INT = (	SELECT	MAX(LastStitchYearWw) LastStitchYearWw 
										FROM	dbo.EsdSupplyByFgWeekSnapshot 
										WHERE	EsdVersionId = @EsdVersionId )

	INSERT INTO dbo.EsdSupplyByDpWeek ([EsdVersionId], SnOPDemandProductId, [YearWw], [UnrestrictedBoh], [SellableBoh], [MPSSellableSupply], [ExcessAdjust], [SupplyDelta], [DiscreteEohExcess], [SellableEoh])
		SELECT	s.EsdVersionID
				,ISNULL(im.[SnOPDemandProductId], i.[SnOPDemandProductId])
				,s.YearWw
				,SUM(s.UnrestrictedBoh) as UnrestrictedBoh
				,SUM(s.SellableBoh) as SellableBoh
				,SUM(s.MPSSellableSupply) as MPSSellableSupply
				,SUM(s.ExcessAdjust) as ExcessAdjust
				,SUM(s.SupplyDelta) as SupplyDelta
				,SUM(s.DiscreteEohExcess) as DiscreteEohExcess
				,SUM(s.SellableEoh) as SellableEoh
		FROM	dbo.EsdSupplyByFgWeekSnapshot s
				INNER JOIN dbo.Items i  ON i.ItemName = s.ItemName		
				LEFT JOIN dbo.Items_Manual im ON im.ItemName = s.ItemName
		WHERE	s.EsdVersionID = @EsdVersionId AND LastStitchYearWw = @LastStitchYearWw
		GROUP BY s.EsdVersionID, ISNULL(im.[SnOPDemandProductId], i.[SnOPDemandProductId]), s.YearWw
	
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
END

