CREATE TABLE [dbo].[SnOPDemandProductHierarchy] (
    [SnOPDemandProductId]            INT           NOT NULL,
    [SnOPDemandProductCd]            VARCHAR (100) NULL,
    [SnOPDemandProductNm]            VARCHAR (100) NULL,
    [IsActive]                       BIT           CONSTRAINT [DF_SnOPDemandProductHierarchy_IsActive] DEFAULT ((1)) NOT NULL,
    [MarketingCodeNm]                VARCHAR (100) NULL,
    [MarketingCd]                    VARCHAR (100) NULL,
    [SnOPBrandGroupNm]               VARCHAR (100) NULL,
    [SnOPComputeArchitectureGroupNm] VARCHAR (100) NULL,
    [SnOPFunctionalCoreGroupNm]      VARCHAR (100) NULL,
    [SnOPGraphicsTierCd]             VARCHAR (100) NULL,
    [SnOPMarketSwimlaneNm]           VARCHAR (100) NULL,
    [SnOPMarketSwimlaneGroupNm]      VARCHAR (100) NULL,
    [SnOPPerformanceClassNm]         VARCHAR (100) NULL,
    [SnOPPackageCd]                  VARCHAR (100) NULL,
    [SnOPPackageFunctionalTypeNm]    VARCHAR (100) NULL,
    [SnOPProcessNm]                  VARCHAR (100) NULL,
    [SnOPProcessNodeNm]              VARCHAR (100) NULL,
    [ProductGenerationSeriesCd]      VARCHAR (100) NULL,
    [SnOPProductTypeNm]              VARCHAR (100) NULL,
    [DesignBusinessNm]               VARCHAR (100) NULL,
    [CreatedOn]                      DATETIME      CONSTRAINT [DF_DemandProductHierarchy_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                      VARCHAR (25)  CONSTRAINT [DF_DemandProductHierarchy_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [DesignNm]                       VARCHAR (255) NULL,
    [SnOPBoardFormFactorCd]          NVARCHAR (30) NULL,
    CONSTRAINT [PK_DemandProductHierarchy] PRIMARY KEY CLUSTERED ([SnOPDemandProductId] ASC)
);


GO



CREATE TRIGGER [dbo].[TrgDemandProductHierarchyCDC]
ON [dbo].[SnOPDemandProductHierarchy]
AFTER INSERT, UPDATE, DELETE
AS BEGIN

----/*********************************************************************************
----    Purpose:        This trigger was designed to monitor the [dbo].[SnOPDemandProductHierarchy] table, in order to give business the view of changes this table
----                    suffers on a daily basis. It loads the [dbo].[SnOPDemandProductHierarchyCDC] table that will be used after in a PBI report with a view.
----    Source:            [dbo].[SnOPDemandProductHierarchy] 
----    Desrtination:   [dbo].[SnOPDemandProductHierarchyCDC] 

----    Called by:      INSERT, UPDATE, DELETE

----    Result sets:    None

----    Parameters: None

----    Return Codes: None

----    Exceptions: None expected

----    Date        User            Description
----***************************************************************************-
----    2023-03-06 rmiralhx        Initial Release

----*********************************************************************************/

    DECLARE @CONST_DataQualityId_DemandProductHierarchyCDC INT = [dbo].[CONST_DataQualityId_DemandProductHierarchyCDC]()
    DECLARE @BatchIdLocal varchar(255)
    SET @BatchIdLocal = 'dbo.TrgDemandProductHierarchyCDC.' + CONVERT(varchar(50), SYSDATETIME()) + '.' + ORIGINAL_LOGIN()

    BEGIN TRY

        EXEC dbo.UspAddApplicationLog
            @LogSource = 'Database'
            , @LogType = 'Info'
            , @Category = 'DQ'
            , @SubCategory = 'Trigger [dbo].[TrgDemandProductHierarchyCDC]'
            , @Message = 'Start'
            , @Status = 'BEGIN'
			, @Exception = NULL
			, @BatchId = @BatchIdLocal;
				
        -- Getting the new rows
        SELECT
            SnOPDemandProductId
            ,SnOPDemandProductCd
            ,SnOPDemandProductNm
            ,MarketingCodeNm
            ,IsActive
            ,MarketingCd
            ,SnOPBrandGroupNm
            ,SnOPComputeArchitectureGroupNm
            ,SnOPFunctionalCoreGroupNm
            ,SnOPGraphicsTierCd
            ,SnOPMarketSwimlaneNm
            ,SnOPMarketSwimlaneGroupNm
            ,SnOPPerformanceClassNm
            ,SnOPPackageCd
            ,SnOPPackageFunctionalTypeNm
            ,SnOPProcessNm
            ,SnOPProcessNodeNm
            ,ProductGenerationSeriesCd
            ,SnOPProductTypeNm
            ,DesignBusinessNm 
            ,DesignNm
            ,CreatedOn
            ,CreatedBy
            ,'INSERT' AS OperationDsc
        INTO #NewRows
        FROM inserted I
        WHERE NOT EXISTS (SELECT 1 FROM deleted D WHERE D.SnOPDemandProductId = I.SnOPDemandProductId)

        -- Getting the old values for updated rows that have changes
        SELECT
            D.SnOPDemandProductId
            ,D.SnOPDemandProductCd
            ,D.SnOPDemandProductNm
            ,D.MarketingCodeNm
            ,D.MarketingCd
            ,D.SnOPBrandGroupNm
            ,D.IsActive
            ,D.SnOPComputeArchitectureGroupNm
            ,D.SnOPFunctionalCoreGroupNm
            ,D.SnOPGraphicsTierCd
            ,D.SnOPMarketSwimlaneNm
            ,D.SnOPMarketSwimlaneGroupNm
            ,D.SnOPPerformanceClassNm
            ,D.SnOPPackageCd
            ,D.SnOPPackageFunctionalTypeNm
            ,D.SnOPProcessNm
            ,D.SnOPProcessNodeNm
            ,D.ProductGenerationSeriesCd
            ,D.SnOPProductTypeNm
            ,D.DesignBusinessNm 
            ,D.DesignNm   
            ,D.CreatedOn
            ,D.CreatedBy
            ,'UPDATE' AS OperationDsc
        INTO #UpdatedRows
        FROM inserted I
        INNER JOIN deleted D ON D.SnOPDemandProductId = I.SnOPDemandProductId
        WHERE
            I.SnOPDemandProductCd <> D.SnOPDemandProductCd
            OR I.SnOPDemandProductNm <> D.SnOPDemandProductNm
            OR I.MarketingCodeNm <> D.MarketingCodeNm
            OR I.MarketingCd <> D.MarketingCd
            OR I.SnOPBrandGroupNm <> D.SnOPBrandGroupNm
            OR I.IsActive <> D.IsActive
            OR I.SnOPComputeArchitectureGroupNm <> D.SnOPComputeArchitectureGroupNm
            OR I.SnOPFunctionalCoreGroupNm <> D.SnOPFunctionalCoreGroupNm
            OR I.SnOPGraphicsTierCd <> D.SnOPGraphicsTierCd
            OR I.SnOPMarketSwimlaneNm <> D.SnOPMarketSwimlaneNm
            OR I.SnOPMarketSwimlaneGroupNm <> D.SnOPMarketSwimlaneGroupNm
            OR I.SnOPPerformanceClassNm <> D.SnOPPerformanceClassNm
            OR I.SnOPPackageCd <> D.SnOPPackageCd
            OR I.SnOPPackageFunctionalTypeNm <> D.SnOPPackageFunctionalTypeNm
            OR I.SnOPProcessNm <> D.SnOPProcessNm
            OR I.SnOPProcessNodeNm <> D.SnOPProcessNodeNm
            OR I.ProductGenerationSeriesCd <> D.ProductGenerationSeriesCd
            OR I.SnOPProductTypeNm <> D.SnOPProductTypeNm
            OR I.DesignBusinessNm <> D.DesignBusinessNm 
            OR I.CreatedOn <> D.CreatedOn
            OR I.CreatedBy <> D.CreatedBy
            OR I.DesignNm <> D.DesignNm 
			
        -- THIS PROCESS DON`T HAVE PHYSICAL DELETION, SO IT WILL BE HANDLED BY UPDATED ROWS

        -- Inserting the rows into the control table
        INSERT INTO dbo.SnOPDemandProductHierarchyCDC
        SELECT
            N.SnOPDemandProductId
            ,N.SnOPDemandProductCd
            ,N.SnOPDemandProductNm
            ,N.MarketingCodeNm
            ,N.IsActive
            ,N.MarketingCd
            ,N.SnOPBrandGroupNm
            ,N.SnOPComputeArchitectureGroupNm
            ,N.SnOPFunctionalCoreGroupNm
            ,N.SnOPGraphicsTierCd
            ,N.SnOPMarketSwimlaneNm
            ,N.SnOPMarketSwimlaneGroupNm
            ,N.SnOPPerformanceClassNm
            ,N.SnOPPackageCd
            ,N.SnOPPackageFunctionalTypeNm
            ,N.SnOPProcessNm
            ,N.SnOPProcessNodeNm
            ,N.ProductGenerationSeriesCd
            ,N.SnOPProductTypeNm
            ,N.DesignBusinessNm 
            ,N.DesignNm 
            ,N.CreatedOn
            ,N.CreatedBy            
            ,N.OperationDsc
            ,GETDATE() AS CDCDate
        FROM #NewRows N
        UNION
        SELECT
           U.SnOPDemandProductId 
            ,U.SnOPDemandProductCd
            ,U.SnOPDemandProductNm
            ,U.MarketingCodeNm
            ,U.IsActive
            ,U.MarketingCd
            ,U.SnOPBrandGroupNm
            ,U.SnOPComputeArchitectureGroupNm
            ,U.SnOPFunctionalCoreGroupNm
            ,U.SnOPGraphicsTierCd
            ,U.SnOPMarketSwimlaneNm
            ,U.SnOPMarketSwimlaneGroupNm
            ,U.SnOPPerformanceClassNm
            ,U.SnOPPackageCd
            ,U.SnOPPackageFunctionalTypeNm
            ,U.SnOPProcessNm
            ,U.SnOPProcessNodeNm
            ,U.ProductGenerationSeriesCd
            ,U.SnOPProductTypeNm
            ,U.DesignBusinessNm 
            ,U.DesignNm
            ,U.CreatedOn
            ,U.CreatedBy            
            ,U.OperationDsc                        
            ,GETDATE() AS CDCDate
        FROM #UpdatedRows U
		
        UPDATE DQC
        SET
            LastSuccessfulRun = GETDATE()
            ,CurrentStatus = 'SUCCESS'
        FROM [dq].[Configuration] DQC
        WHERE DQC.Id = @CONST_DataQualityId_DemandProductHierarchyCDC

        EXEC dbo.UspAddApplicationLog
            @LogSource = 'Database'
            , @LogType = 'Info'
            , @Category = 'DQ'
            , @SubCategory = 'Trigger [dbo].[TrgDemandProductHierarchyCDC]'
            , @Message = 'Finish'
            , @Status = 'END'
            , @Exception = NULL
            , @BatchId = @BatchIdLocal;

    END TRY
    BEGIN CATCH

        UPDATE DQC
        SET
            CurrentStatus = 'FAILURE'
        FROM [dq].[Configuration] DQC
        WHERE DQC.Id = @CONST_DataQualityId_DemandProductHierarchyCDC

        EXEC dbo.UspAddApplicationLog
            @LogSource = 'Database'
            , @LogType = 'Info'
            , @Category = 'DQ'
            , @SubCategory = 'Trigger [dbo].[TrgDemandProductHierarchyCDC]'
            , @Message = 'Failure'
            , @Status = 'ERROR'
            , @Exception = @@ERROR
            , @BatchId = @BatchIdLocal;

    END CATCH

END