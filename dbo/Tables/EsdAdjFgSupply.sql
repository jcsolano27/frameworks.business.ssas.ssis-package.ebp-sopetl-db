CREATE TABLE [dbo].[EsdAdjFgSupply] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearMm]              INT          NOT NULL,
    [YearQq]              INT          NULL,
    [AdjFgSupply]         FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_EsdAdjFgSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_EsdAdjFgSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdAdjFgSupply] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearMm] ASC),
    CONSTRAINT [FK_EsdAdjFgSupply_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

