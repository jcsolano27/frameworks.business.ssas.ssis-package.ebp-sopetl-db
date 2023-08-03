CREATE TABLE [sop].[ItemPrqMilestone] (
    [PlanningSupplyPackageVariantId] INT            NOT NULL,
    [SourceProjectNm]                NVARCHAR (255) NOT NULL,
    [MilestoneTypeCd]                NVARCHAR (100) NOT NULL,
    [PrqMilestoneDtm]                DATETIME       NOT NULL,
    [NpiInd]                         BIT            NOT NULL,
    [CreatedOnDtm]                   DATETIME       CONSTRAINT [DF_sopItemPrqMilestones_CreatedOnDtm] DEFAULT (getutcdate()) NOT NULL,
    [CreatedByNm]                    NVARCHAR (25)  CONSTRAINT [DF_sopItemPrqMilestones_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]                  DATETIME       CONSTRAINT [DF_sopItemPrqMilestoness_ModifiedOnDtm] DEFAULT (getutcdate()) NULL,
    [ModifiedByNm]                   NVARCHAR (25)  CONSTRAINT [DF_sopItemPrqMilestones_ModifiedByNm] DEFAULT (original_login()) NULL,
    PRIMARY KEY CLUSTERED ([PlanningSupplyPackageVariantId] ASC, [MilestoneTypeCd] ASC)
);

