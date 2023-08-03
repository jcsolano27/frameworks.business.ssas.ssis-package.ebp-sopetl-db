CREATE TABLE [dbo].[ProfitCenterSupplyDistributionParms] (
    [ProfitCenterCd] INT          NOT NULL,
    [DistCategoryId] INT          NULL,
    [DistCategory]   VARCHAR (50) NULL,
    [Priority]       INT          NULL,
    [Woi]            FLOAT (53)   NULL,
    [CreatedOn]      DATETIME     CONSTRAINT [DF_ProfitCenterSupplyDistributionParms_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]      VARCHAR (25) CONSTRAINT [DF_ProfitCenterSupplyDistributionParms_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ProfitCenterSupplyDistributionParms] PRIMARY KEY CLUSTERED ([ProfitCenterCd] ASC),
    CONSTRAINT [FK_ProfitCenterSupplyDistributionParms_ProfitCenters] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [dbo].[ProfitCenterHierarchy] ([ProfitCenterCd])
);

