
CREATE   PROC [sop].[UspLoadStgTmgfDemand]
AS

/*********************************************************************************
	Purpose: Load data to sop.StgTmgfDemand

    Date        User            Description
***************************************************************************-
    2023-06-23	fjunio2x        Initial Release
*********************************************************************************/
SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY
    -- Error and transaction handling setup ********************************************************
    DECLARE @ReturnErrorMessage VARCHAR(MAX),
            @ErrorLoggedBy VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),
            @CurrentAction VARCHAR(4000),
            @DT VARCHAR(50) = SYSDATETIME(),
            @Message VARCHAR(MAX);

	-- Variables Required for ETL ------------------------------------------------------------------
	DECLARE 
	    @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf  INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeCbf]())
	  , @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf  INT = (SELECT [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeCbf]())
	  , @CONST_KeyFigureId_IfsRequestVolumeBe        INT = (SELECT [sop].[CONST_KeyFigureId_IfsRequestVolumeBe]())
	  , @CONST_KeyFigureId_IfsRequestVolumeFe        INT = (SELECT [sop].[CONST_KeyFigureId_IfsRequestVolumeFe]())
	  , @CONST_KeyFigureId_FgPrice                   INT = (SELECT [sop].[CONST_KeyFigureId_FgPrice]())
	  , @CONST_KeyFigureId_WaferPrice                INT = (SELECT [sop].[CONST_KeyFigureId_WaferPrice]())
	  , @CONST_SourceSystemId_Svd                    INT = (SELECT [sop].[CONST_SourceSystemId_Svd]());
;
	------------------------------------------------------------------------------------------------
	
	-- Clear the stagint table to insert new records
	TRUNCATE TABLE [sop].[StgTmgfDemand]


	-- Key figures 16 - ProdCo Request Volume/BE/CBF ### Using PlanningFigure table until the definitive source
	INSERT INTO [sop].[StgTmgfDemand]
		(
		  PlanningMonthNbr
		, PlanVersionId
		, ProductId
		, ProfitCenterCd
		, KeyFigureId
		, TimePeriodId
		, SourceSystemId
		, Quantity
		)
	SELECT PlanningMonthNbr
		 , PlanVersionId
		 , ProductId
		 , ProfitCenterCd
		 , KeyFigureId
		 , TimePeriodId
		 , @CONST_SourceSystemId_Svd
		 , Quantity
	FROM   sop.PlanningFigure
	WHERE  KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeBeCbf;


	-- Key figures 18 - ProdCo Request Volume/FE/CBF ### Using PlanningFigure table until the definitive source
	INSERT INTO [sop].[StgTmgfDemand]
		(
		  PlanningMonthNbr
		, PlanVersionId
		, ProductId
		, ProfitCenterCd
		, KeyFigureId
		, TimePeriodId
		, SourceSystemId
		, Quantity
		)
	SELECT PlanningMonthNbr
		 , PlanVersionId
		 , ProductId
		 , ProfitCenterCd
		 , KeyFigureId
		 , TimePeriodId
		 , @CONST_SourceSystemId_Svd
		 , Quantity
	FROM   sop.PlanningFigure
	WHERE  KeyFigureId = @CONST_KeyFigureId_ProdCoRequestVolumeFeCbf;


	-- Key figures 27 - IFS Request Volume/BE ### Using PlanningFigure table until the definitive source
	INSERT INTO [sop].[StgTmgfDemand]
		(
		  PlanningMonthNbr
		, PlanVersionId
		, ProductId
		, ProfitCenterCd
		, KeyFigureId
		, TimePeriodId
		, SourceSystemId
		, Quantity
		)
	SELECT PlanningMonthNbr
		 , PlanVersionId
		 , ProductId
		 , ProfitCenterCd
		 , KeyFigureId
		 , TimePeriodId
		 , @CONST_SourceSystemId_Svd
		 , Quantity
	FROM   sop.PlanningFigure
	WHERE  KeyFigureId = @CONST_KeyFigureId_IfsRequestVolumeBe;


	-- Key figures 28 - IFS Request Volume/FE ### Using PlanningFigure table until the definitive source
	INSERT INTO [sop].[StgTmgfDemand]
		(
		  PlanningMonthNbr
		, PlanVersionId
		, ProductId
		, ProfitCenterCd
		, KeyFigureId
		, TimePeriodId
		, SourceSystemId
		, Quantity
		)
	SELECT PlanningMonthNbr
		 , PlanVersionId
		 , ProductId
		 , ProfitCenterCd
		 , KeyFigureId
		 , TimePeriodId
		 , @CONST_SourceSystemId_Svd
		 , Quantity
	FROM   sop.PlanningFigure
	WHERE  KeyFigureId = @CONST_KeyFigureId_IfsRequestVolumeFe;



	-- Key figures 38 - FG Price ### Using PlanningFigure table until the definitive source
	INSERT INTO [sop].[StgTmgfDemand]
		(
		  PlanningMonthNbr
		, PlanVersionId
		, ProductId
		, ProfitCenterCd
		, KeyFigureId
		, TimePeriodId
		, SourceSystemId
		, Quantity
		)
	SELECT PlanningMonthNbr
		 , PlanVersionId
		 , ProductId
		 , ProfitCenterCd
		 , KeyFigureId
		 , TimePeriodId
		 , @CONST_SourceSystemId_Svd
		 , Quantity
	FROM   sop.PlanningFigure
	WHERE  KeyFigureId = @CONST_KeyFigureId_FgPrice;


	-- Key figures 39 - Wafer Price ### Using PlanningFigure table until the definitive source
	INSERT INTO [sop].[StgTmgfDemand]
		(
		  PlanningMonthNbr
		, PlanVersionId
		, ProductId
		, ProfitCenterCd
		, KeyFigureId
		, TimePeriodId
		, SourceSystemId
		, Quantity
		)
	SELECT PlanningMonthNbr
		 , PlanVersionId
		 , ProductId
		 , ProfitCenterCd
		 , KeyFigureId
		 , TimePeriodId
		 , @CONST_SourceSystemId_Svd
		 , Quantity
	FROM   sop.PlanningFigure
	WHERE  KeyFigureId = @CONST_KeyFigureId_WaferPrice;

END TRY

BEGIN CATCH
    SELECT @ReturnErrorMessage
        = 'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
          + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
          + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
          + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');

    EXEC sop.UspAddApplicationLog @LogSource = 'Database',
                                  @LogType = 'Error',
                                  @Category = 'Etl',
                                  @SubCategory = @ErrorLoggedBy,
                                  @Message = @CurrentAction,
                                  @Status = 'ERROR',
                                  @Exception = @ReturnErrorMessage;

    THROW;
END CATCH;