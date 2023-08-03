
--*************************************************************************************************************************************
--    Purpose:	Generate data in [dbo].[StgEsdBonusableSupply].

--    Date          User            Description
--************************************************************************************************************************************
--    2023-03-27	fjunio2x        Initial Release
--************************************************************************************************************************************


CREATE   PROCEDURE [dbo].[UspEtlLoadStgEsdBonusableSupply]
    @EsdVersionId int
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
/*
    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'BEGIN'
      , @Exception = NULL
      , @BatchId = @BatchId;
*/

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

    
	DECLARE @SourceApplicationName Varchar(25) = 'ESD'
		  , @SourceVersionId       int         = 0
		  , @ResetWw               int         = 0
		  , @ActualQuarter         int         = 0;
	

	SELECT @ResetWw = ISNULL (ResetWw, DemandWw) 
	FROM   dbo.EsdBaseVersions Base                                                            JOIN 
	       dbo.EsdVersions     Esd     ON Esd.EsdBaseVersionId    = Base.EsdBaseVersionId      JOIN 
		   dbo.PlanningMonths  ResetWw ON ResetWw.PlanningMonthId = Base.PlanningMonthId
    WHERE  EsdVersionId =  @EsdVersionid


	SELECT @ActualQuarter = V.YearQQ
	FROM
	    (
		Select TOP 1 YearQq 
		FROM Intelcalendar Cal
		JOIN 
		(
		SELECT PlanningMonth 
		FROM EsdBaseVersions Base                                                       JOIN 
			 EsdVersions     Esd     ON Esd.EsdBaseVersionId = Base.EsdBaseVersionId    JOIN 
			 PlanningMonths  ResetWw ON ResetWw.PlanningMonthId = Base.PlanningMonthId
		WHERE EsdVersionId =  @EsdVersionId
		) PlanMonth
		on PlanMonth.PlanningMonth = Cal.YearMonth
		) AS V

--	If @EsdVersionId Is Null 
--	Begin
--		RaiseError (15600,-1,-1, 'a');--('There is no products mapped',1,1)
--   End

    DELETE FROM [dbo].[StgEsdBonusableSupply]
	WHERE EsdVersionId = @EsdVersionId;


	INSERT INTO [dbo].[StgEsdBonusableSupply]
		(
		  EsdVersionId
        , SourceApplicationName
		, SourceVersionId
		, ResetWw
        , WhatIfScenarioName
        , SDAFamily
        , ItemName
        , ItemClass
        , ItemDescription
        , SnOPDemandProductNm
        , Yearqq
        , ExcessToMpsInvTargetCum
	)
	(
		Select Distinct @EsdVersionId                                   AS EsdVersionId
			 , @SourceApplicationName                                   AS SourceApplicationName
			 , @SourceVersionId                                         AS SourceVersionId
			 , @ResetWw                                                 AS ResetWw
			 , 'Base'                                                   AS WhatIfScenarioName
			 , Fab.SdaFamilies     COLLATE SQL_Latin1_General_CP1_CI_AS AS SDAFamily
			 , Fab.Item            COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemName
			 , 'DIE PREP'                                               AS ItemClass
			 , Fab.ItemName        COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , Prod.SnOPDemandProductNm                                 AS SnOPDemandProductNm
			 , Cal.FiscalYearQuarterNbr                                 AS Yearqq
			 , Fab.TotalIsExcess                                        AS ExcessToMpsInvTargetCum
		From   [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_FabMps] Fab                                                                          LEFT JOIN
			   [dbo].[StgDiePrepItemsMap]         Die                   On Die.ItemDescription      = Fab.Item COLLATE SQL_Latin1_General_CP1_CI_AS  LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod                  On Prod.SnOPDemandProductId = Die.SnOPDemandProductId                        JOIN
			   [dbo].[SopFiscalCalendar]          Cal                   On Cal.FiscalYearMonthNbr   = Fab.YearMonth
		Where  Die.ItemId Is Not Null
		  And  Fab.ItemClass              = 'DIE PREP'
		  And  Die.SnOPDemandProductId    Is Not Null -- Only mapped items
		  And  IsNull(Die.RemoveInd,0)    <> 1        -- Only valid items
		  And  Round(Fab.TotalIsExcess,5) >= 0
		  And  Cal.FiscalYearQuarterNbr   >= @ActualQuarter
		  And  Not Exists ( Select 1 From [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_OneMps] OneMps Where OneMps.Item = Fab.Item)
		UNION
		Select Distinct @EsdVersionId                                   AS EsdVersionId
			 , @SourceApplicationName                                   AS SourceApplicationName
			 , @SourceVersionId                                         AS SourceVersionId 
			 , @ResetWw                                                 AS ResetWw
			 , 'Base'                                                   AS WhatIfScenarioName
			 , OneMps.SdaFamilies  COLLATE SQL_Latin1_General_CP1_CI_AS AS SDAFamily
			 , OneMps.Item         COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemName
			 , 'DIE PREP'                                               AS ItemClass
			 , OneMps.ItemName     COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , Prod.SnOPDemandProductNm                                 AS SnOPDemandProductNm
			 , Cal.FiscalYearQuarterNbr                                 AS Yearqq
			 , OneMps.TotalIsExcess                                     AS ExcessToMpsInvTargetCum
		From   [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_OneMps] OneMps                                                                              LEFT JOIN
			   [dbo].[StgDiePrepItemsMap]         Die                   On Die.ItemDescription      = OneMps.Item COLLATE SQL_Latin1_General_CP1_CI_AS      LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod                  On Prod.SnOPDemandProductId = Die.SnOPDemandProductId                               JOIN
			   [dbo].[SopFiscalCalendar]          Cal                   On Cal.FiscalYearMonthNbr   = OneMps.YearMonth COLLATE SQL_Latin1_General_CP1_CI_AS
		Where  Die.ItemId Is Not Null
		  And  OneMps.ItemClass              = 'DIEPREP'
		  And  Die.SnOPDemandProductId       Is Not Null -- Only mapped items
		  And  IsNull(Die.RemoveInd,0)       <> 1        -- Only valid items
		  And  Round(OneMps.TotalIsExcess,5) >= 0
		  And  Cal.FiscalYearQuarterNbr      >= @ActualQuarter
		UNION 
		Select DISTINCT @EsdVersionId                                   AS EsdVersionId
			 , @SourceApplicationName                                   AS SourceApplicationName
			 , @SourceVersionId                                         AS SourceVersionId
			 , @ResetWw                                                 AS ResetWw
			 , 'Base'                                                   AS WhatIfScenarioName
			 , 'Compass'                                                AS SdaFamily
			 , Compass.ItemId      COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemName
			 , 'DIE PREP'                                               AS ItemClass
			 , Die.ItemDescription COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , Prod.SnOPDemandProductNm                                 AS SnOPDemandProductNm
			 , Cal.FiscalYearQuarterNbr                                 AS Yearqq
			 , DieEsuExcess / 1000                                      AS ExcessToMpsInvTargetCum
		FROM   [dbo].[CompassDieEsuExcess]        Compass                                                                                                  LEFT JOIN
			   [dbo].[StgDiePrepItemsMap]         Die                   On Die.ItemId               = Compass.ItemId COLLATE SQL_Latin1_General_CP1_CI_AS  LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod                  On Prod.SnOPDemandProductId = Die.SnOPDemandProductId                              JOIN
			   [dbo].[SopFiscalCalendar]          Cal                   On Cal.Workweek             = Compass.YearWW
               -- Used to get only the last WW of the quarter data.
                JOIN
                (
                SELECT YearQQ, MAX(YearWw) AS YearWw FROM dbo.intelcalendar
                GROUP BY YearQQ
                ) CalLastWw
                ON CalLastWw.YearWw = Compass.YearWW
		WHERE Compass.EsdVersionId            = @EsdVersionId
		  And  Die.SnOPDemandProductId        Is Not Null -- Only mapped items
		  And  IsNull(Die.RemoveInd,0)        <> 1        -- Only valid items
		  And  Round((DieEsuExcess / 1000),5) > 0
		  And  Cal.FiscalYearQuarterNbr       >= @ActualQuarter
	);



	INSERT INTO [dbo].[StgEsdBonusableSupply]
		(
		  EsdVersionId
        , SourceApplicationName
		, SourceVersionId
		, ResetWw
        , WhatIfScenarioName
        , SDAFamily
        , ItemName
        , ItemClass
        , ItemDescription
        , SnOPDemandProductNm
        , Yearqq
        , ExcessToMpsInvTargetCum
	)
	(
		Select Distinct @EsdVersionId                                   AS EsdVersionId
			 , @SourceApplicationName                                   AS SourceApplicationName
			 , @SourceVersionId                                         AS SourceVersionId
			 , @ResetWw                                                 AS ResetWw
			 , 'Base'                                                   AS WhatIfScenarioName
			 , Fab.SdaFamilies     COLLATE SQL_Latin1_General_CP1_CI_AS AS SDAFamily
			 , Fab.Item            COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemName
			 , Fab.ItemClass       COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemClass
			 , Fab.ItemName        COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , Prod.SnOPDemandProductNm                                 AS SnOPDemandProductNm
			 , Cal.FiscalYearQuarterNbr                                 AS Yearqq
			 , Fab.TotalIsExcess                                        AS ExcessToMpsInvTargetCum
		From   [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_FabMps] Fab                                                                          LEFT JOIN
			   [dbo].[Items]                      It                    On It.ItemName              = Fab.Item COLLATE SQL_Latin1_General_CP1_CI_AS  LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod                  On Prod.SnOPDemandProductId = It.SnOPDemandProductId                         JOIN
			   [dbo].[SopFiscalCalendar]          Cal                   On Cal.FiscalYearMonthNbr   = Fab.YearMonth
		Where  Fab.SdaFamilies            <> '(blank)'
		  And  Prod.SnOPDemandProductNm   Is Not Null
		  And  Fab.ItemClass              = 'FG'
		  And  Round(Fab.TotalIsExcess,0) >= 0
		  And  Cal.FiscalYearQuarterNbr   >= @ActualQuarter
		  And  Not Exists ( Select 1 From [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_OneMps] OneMps Where OneMps.Item = Fab.Item)
		UNION
		Select Distinct @EsdVersionId                                   AS EsdVersionId
			 , @SourceApplicationName                                   AS SourceApplicationName
			 , @SourceVersionId                                         AS SourceVersionId 
			 , @ResetWw                                                 AS ResetWw
			 , 'Base'                                                   AS WhatIfScenarioName
			 , OneMps.SdaFamilies  COLLATE SQL_Latin1_General_CP1_CI_AS AS SDAFamily
			 , OneMps.Item         COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemName
			 , OneMps.ItemClass    COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemClass
			 , OneMps.ItemName     COLLATE SQL_Latin1_General_CP1_CI_AS AS ItemDescription
			 , Prod.SnOPDemandProductNm                                 AS SnOPDemandProductNm
			 , Cal.FiscalYearQuarterNbr                                 AS Yearqq
			 , OneMps.TotalIsExcess                                     AS ExcessToMpsInvTargetCum
		From   [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_Excess_OneMps] OneMps                                                                              LEFT JOIN
			   [dbo].[Items]                      It                    On It.ItemName              = OneMps.Item COLLATE SQL_Latin1_General_CP1_CI_AS      LEFT JOIN
			   [dbo].[SnOPDemandProductHierarchy] Prod                  On Prod.SnOPDemandProductId = It.SnOPDemandProductId                                JOIN
			   [dbo].[SopFiscalCalendar]          Cal                   On Cal.FiscalYearMonthNbr   = OneMps.YearMonth COLLATE SQL_Latin1_General_CP1_CI_AS
		Where  OneMps.SdaFamilies            <> '(blank)'
		  And  OneMps.SdaFamilies            Not Like 'PONTE VECCHIO%'
		  And  Prod.SnOPDemandProductNm      Is Not Null
		  And  OneMps.ItemClass              = 'FG'
		  And  Round(OneMps.TotalIsExcess,0) >= 0
		  And  Cal.FiscalYearQuarterNbr      >= @ActualQuarter
	)


	UPDATE [dbo].[StgEsdBonusableSupply] 
	SET    BonusPercent = 0 
	WHERE  EsdVersionId = @EsdVersionId;


	-- 2023-05-24 Hal ask to create this update - I need to make sure that the Item description is not NULL for the items that come from Compass that don't have a description and use the item name.
	UPDATE [dbo].[StgEsdBonusableSupply] 
    SET    ItemDescription = ItemName 
    WHERE  EsdVersionId    = @EsdVersionId
      AND  ItemClass       = 'DIE PREP'  
      AND  ItemDescription IS NULL;


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
      , @BatchId = 1;

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
      , @Category = 'UspEtlLoadStgEsdBonusableSupply'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @CurrentAction
      , @Status = 'ERROR'
      , @Exception = @ReturnErrorMessage
      , @BatchId = 1;

    -- re-throw the error
    THROW;

END CATCH;

