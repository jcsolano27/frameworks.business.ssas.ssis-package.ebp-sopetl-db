CREATE TABLE [dbo].[EsdAdjSellableSupply] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearMm]              INT          NOT NULL,
    [YearQq]              INT          NULL,
    [AdjSellableSupply]   FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_EsdAdjSellableSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_EsdAdjSellableSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdAdjSellableSupply] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearMm] ASC),
    CONSTRAINT [FK_EsdAdjSellableSupply _EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

