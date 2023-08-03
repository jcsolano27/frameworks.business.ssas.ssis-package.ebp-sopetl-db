--***************************************************************************************************************************************************
--    Purpose:	Transforms the data of the table [dbo].[ItemCharacteristicDetail] to the format expected in ESD UI.  
--				The result is inserted in table [dbo].[StgDiePrepItemsMap].

--    Date          User            Description
--*********************************************************************************
--    2023-03-21	fjunio2x        Initial Release
--    2023-07-07	hmanentx        Filtering rows to only allow the DIE PREP data to be inserted in the final table
--*********************************************************************************

CREATE   PROC [dbo].[UspEtlLoadStgDiePrepItemsMap]
    @BatchId VARCHAR(100) = NULL
  , @SourceApplicationName VARCHAR(50) = 'ESD'
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
      , @TableName = 'dbo.StgExcessCompassFabMps'
	  , @ProcessingStarted = 1
      , @BatchId = @BatchId
      , @ParameterList = @ParameterList;
*/

	SELECT @CurrentAction = 'Performing work';

    -- Clean just items NOT MAPPED
	Delete [dbo].[StgDiePrepItemsMap]
	Where ItemId In 
		(
		Select [ProductDataManagementItemId]
		From   dbo.ItemCharacteristicDetail ICD
		Where	Not Exists ( Select 1 From dbo.StgDiePrepItemsMap DPIM Where DPIM.ItemId = ICD.ProductDataManagementItemId And (DPIM.SnOPDemandProductId Is Not Null Or DPIM.RemoveInd Is Not Null) )
		AND		ICD.ProductDataManagementItemClassNm = 'UPI_DIE_PREP'
		);

	-- Include new information from Hana	   
	Insert Into [dbo].[StgDiePrepItemsMap]
		(
		  ItemId
		, ItemDescription
		, MMCodeName
		, DLCPProc
		)
	Select ItemId
         , ItemDescription
         , MM_CODE_NAME
         , DLCP_PROC
	From (
           Select [ProductDataManagementItemId] ItemId
		        , Min(Case [CharacteristicNm] When 'MM-CODE-NAME'     Then [CharacteristicValue] End) MM_CODE_NAME
				, Min(Case [CharacteristicNm] When 'DLCP_PROC'        Then [CharacteristicValue] End) DLCP_PROC
				, Min(Case [CharacteristicNm] When 'OLD_MATERIAL_NBR' Then [CharacteristicValue] When 'Description' Then [CharacteristicValue] End) ItemDescription
           From   dbo.ItemCharacteristicDetail ICD
           Where
				Not Exists ( Select 1 From StgDiePrepItemsMap DPIM Where DPIM.ItemId = ICD.ProductDataManagementItemId And (DPIM.SnOPDemandProductId Is Not Null Or DPIM.RemoveInd Is Not Null) )
				AND ICD.ProductDataManagementItemClassNm = 'UPI_DIE_PREP'
           Group By [ProductDataManagementItemId]
         ) AS V
	Where   V.ItemId           Is Not Null
		And V.ItemDescription  Is Not Null
		And V.MM_CODE_NAME     Is Not Null
		And V.DLCP_PROC        Is Not Null;

/*	
	SELECT @RowCount = COUNT(*) FROM [dbo].[StgExcessCompassFabMps];

    EXEC dbo.UspEtlMergeTableLoadStatus
        @Debug = @Debug
      , @BatchRunId = @BatchRunId
      , @SourceApplicationName = @SourceApplicationName
      , @TableName = 'dbo.StgExcessCompassFabMps'
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