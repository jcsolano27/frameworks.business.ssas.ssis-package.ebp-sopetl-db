CREATE TABLE [dbo].[EsdAdjAtmConstrainedSupply] (
    [EsdVersionId]            INT          NOT NULL,
    [SnOPDemandProductId]     INT          NOT NULL,
    [YearMm]                  INT          NOT NULL,
    [YearQq]                  INT          NULL,
    [AdjAtmConstrainedSupply] FLOAT (53)   NULL,
    [CreatedOn]               DATETIME     CONSTRAINT [DF_EsdDataAdjAtmConstrainedSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]               VARCHAR (25) CONSTRAINT [DF_EsdDataAdjAtmConstrainedSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdDataAdjAtmConstrainedSupply] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearMm] ASC),
    CONSTRAINT [FK_EsdDataAdjAtmConstrainedSupply_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

