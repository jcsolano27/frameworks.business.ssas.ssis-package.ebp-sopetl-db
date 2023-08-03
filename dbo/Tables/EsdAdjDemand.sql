CREATE TABLE [dbo].[EsdAdjDemand] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearMm]              INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [YearQq]              INT          NULL,
    [AdjDemand]           FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_EsdAdjDemand_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_EsdAdjDemand_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdAdjDemand] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearMm] ASC, [ProfitCenterCd] ASC),
    CONSTRAINT [FK_EsdAdjDemand_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

