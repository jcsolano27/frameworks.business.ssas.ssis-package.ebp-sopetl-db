/*
//Purpose  : This proc check TotalSupply delta and SellableSupply delta before and after the supply distribution
//Author   : Steve Liu
//Date     : July 26, 2021

//Versions : 

// Version		Date			Modified by           Reason
// =======		====			===========           ======
//  1.0 		July 26, 2021	Steve Liu			  Initial Version
//  2.0			Sept 07, 2022	Steve Liu			  Refactored from UspJdVsFsd
//---------------------------------------------------------------------// 
*/

CREATE PROCEDURE dbo.UspDQSupplyDeltaBeforeAfterDistribution
	@EsdVersionId INT 
AS
BEGIN
/* Test Harness
	EXEC dbo.UspDQSupplyDeltaBeforeAfterDistribution @EsdVersionId = 158
--*/

	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;
	SET NUMERIC_ROUNDABORT OFF;	

	BEGIN TRY
		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
			, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
			, @CurrentAction      VARCHAR(4000)
			, @DT                 VARCHAR(50) = (SELECT SYSDATETIME());

/*Debug Parameters
	SET ANSI_WARNINGS OFF
	DECLARE
		@ReturnErrorMessage VARCHAR(MAX)
		, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		, @CurrentAction      VARCHAR(4000)
		, @DT                 VARCHAR(50) = (SELECT SYSDATETIME());

	DECLARE @EsdVersionId INT = 154, @StitchYearWw INT = 202240, @Debug BIT = 1
--*/
		DECLARE @BatchId VARCHAR(MAX) = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();
		DECLARE @CONST_ParameterId_ToTalSupply INT  = (SELECT dbo.CONST_ParameterId_TotalSupply())
		DECLARE @CONST_ParameterId_SellableSupply INT  = (SELECT dbo.CONST_ParameterId_SellableSupply())

		DROP TABLE If Exists #AllKeys

		SELECT	DISTINCT EsdVersionId, SnOPDemandProductId, YearWw
		INTO	#AllKeys
		FROM	dbo.EsdTotalSupplyAndDemandByDpWeek tsd
		WHERE	EsdVersionId = @EsdVersionId
		UNION 
		SELECT	DISTINCT SourceVersionId AS EsdVersionId, SnOPDemandProductId, YearWw
		FROM	SupplyDistribution
		WHERE	SourceVersionId = @EsdVersionId

		SELECT  [MarketingCodeNm], [SnOPComputeArchitectureGroupNm], [SnOPProcessNodeNm], [SnOPProductTypeNm], ph.SnOPDemandProductNm, t1.SnOPDemandProductId, 
				ic.YearQq, ic.YearMonth AS YearMm, t1.YearWw, 
				t1.SellableSupply AS SellableSupply_before, t3.SellableSupply AS SellableSupply_after,
				t1.TotalSupply AS TotalSupply_before, t2.TotalSupply AS TotalSupply_after
		FROM	#AllKeys k
				INNER JOIN dbo.IntelCalendar ic On ic.YearWw = k.YearWw
				LEFT JOIN 
				(
					SELECT	DISTINCT SnOPDemandProductId, YearWw, SUM(TotalSupply) AS TotalSupply, SUM(SellableSupply) AS SellableSupply
					FROM	dbo.EsdTotalSupplyAndDemandByDpWeek 
					WHERE	Esdversionid = @EsdVersionId
					GROUP BY SnOPDemandProductId, YearWw
				) t1 ON t1.SnOPDemandProductId = k.SnOPDemandProductId AND t1.YearWw = k.YearWw
				LEFT JOIN
				(
					SELECT	DISTINCT SnOPDemandProductId, YearWw , SUM(Quantity) AS TotalSupply
					FROM	dbo.SupplyDistribution 
					WHERE	SourceVersionId = @EsdVersionId AND SupplyParameterId = @CONST_ParameterId_ToTalSupply
					GROUP BY SnOPDemandProductId, YearWw
				) t2 on t2.SnOPDemandProductId = k.SnOPDemandProductId and t2.YearWw = k.YearWw
				LEFT JOIN
				(
					SELECT	DISTINCT SnOPDemandProductId, YearWw , SUM(Quantity) AS SellableSupply
					FROM	dbo.SupplyDistribution 
					WHERE	SourceVersionId = @EsdVersionId AND SupplyParameterId = @CONST_ParameterId_SellableSupply
					GROUP BY SnOPDemandProductId, YearWw
				) t3 on t3.SnOPDemandProductId = k.SnOPDemandProductId and t3.YearWw = k.YearWw
				LEFT JOIN dbo.SnOPDemandProductHierarchy ph ON ph.SnOPDemandProductId = t1.SnOPDemandProductId
		WHERE	(ABS(t2.TotalSupply - t1.TotalSupply ) > 1 OR ABS(t3.SellableSupply - t1.SellableSupply ) > 1)
				--AND k.YearWw > 202240
		ORDER BY 1, 5

		RETURN 0;
	END TRY
	BEGIN CATCH
		SELECT	@ReturnErrorMessage = 
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

		-- Send the exact exception to the caller
		THROW;
	
	END CATCH;
END

--GO

--select * from #Demand where YearWW < 202131 and SnOPDemandProductId = 'SvrWS Alder Lake PCH-S'
--select * from #Billing where YearWW < 202131 and SnOPDemandProductId = 'SvrWS Alder Lake PCH-S'
--select * from #EsdDataDemandStitchByStfMonthFsd where SnOPDemandProductId = 'SvrWS Alder Lake PCH-S' order by YearMm

