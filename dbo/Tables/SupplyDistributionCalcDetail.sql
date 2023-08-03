CREATE TABLE [dbo].[SupplyDistributionCalcDetail] (
    [PlanningMonth]                 INT          NOT NULL,
    [SupplyParameterId]             INT          NOT NULL,
    [SourceApplicationId]           INT          NOT NULL,
    [SourceVersionId]               INT          NOT NULL,
    [SnOPDemandProductId]           INT          NOT NULL,
    [YearWw]                        INT          NOT NULL,
    [ProfitCenterCd]                INT          NOT NULL,
    [Supply]                        FLOAT (53)   NULL,
    [PcSupply]                      FLOAT (53)   NULL,
    [RemainingSupply]               FLOAT (53)   NULL,
    [DistCategoryId]                INT          NULL,
    [Priority]                      INT          NULL,
    [Demand]                        FLOAT (53)   NULL,
    [Boh]                           FLOAT (53)   NULL,
    [OneWoi]                        FLOAT (53)   NULL,
    [PcWoi]                         FLOAT (53)   NULL,
    [ProdWoi]                       FLOAT (53)   NULL,
    [OffTopTargetInvQty]            FLOAT (53)   NULL,
    [ProdTargetInvQty]              FLOAT (53)   NULL,
    [OffTopTargetBuildQty]          FLOAT (53)   NULL,
    [ProdTargetBuildQty]            FLOAT (53)   NULL,
    [FairSharePercent]              FLOAT (53)   NULL,
    [AllPcPercent]                  FLOAT (53)   NULL,
    [AllPcPercentForNegativeSupply] FLOAT (53)   NULL,
    [DistCnt]                       INT          NULL,
    [IsTargetInvCovered]            BIT          NULL,
    [CreatedOn]                     DATETIME     CONSTRAINT [DF_EsdSupplyDistCalcDetail_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                     VARCHAR (25) CONSTRAINT [DF_EsdSupplyDistCalcDetail_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SupplyDistributionCalcDetail_1] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SourceApplicationId] ASC, [SourceVersionId] ASC, [SnOPDemandProductId] ASC, [SupplyParameterId] ASC, [YearWw] ASC, [ProfitCenterCd] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IdxSupplyDistributionCalcDetailSourceApplicationIdSourceVersionId]
    ON [dbo].[SupplyDistributionCalcDetail]([SourceApplicationId] ASC, [SourceVersionId] ASC);

