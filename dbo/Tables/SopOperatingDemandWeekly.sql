CREATE TABLE [dbo].[SopOperatingDemandWeekly] (
    [SourceApplicationName]  VARCHAR (25) NOT NULL,
    [SopOperatingDemandWeek] INT          NOT NULL,
    [SnOPDemandProductId]    INT          NOT NULL,
    [ProfitCenterCd]         INT          NOT NULL,
    [YearWw]                 INT          NOT NULL,
    [Quantity]               FLOAT (53)   NULL,
    [CreatedOn]              DATETIME     CONSTRAINT [DF_SopOperatingDemandWeekly_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25) CONSTRAINT [DF_SopOperatingDemandWeekly_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]             DATETIME     NULL,
    CONSTRAINT [PK_SopOperatingDemandWeekly] PRIMARY KEY CLUSTERED ([SopOperatingDemandWeek] ASC, [SnOPDemandProductId] ASC, [ProfitCenterCd] ASC, [YearWw] ASC),
    CONSTRAINT [FK_SopOperatingDemandWeekly_ProfitCenters] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [dbo].[ProfitCenterHierarchy] ([ProfitCenterCd]),
    CONSTRAINT [FK_SopOperatingDemandWeekly_SnOPDemandProductHierarchy] FOREIGN KEY ([SnOPDemandProductId]) REFERENCES [dbo].[SnOPDemandProductHierarchy] ([SnOPDemandProductId])
);

