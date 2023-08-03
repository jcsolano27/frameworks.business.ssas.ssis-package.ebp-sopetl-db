CREATE TABLE [dbo].[MpsAdjDemand] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [SourceVersionId]       INT          NOT NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [LocationName]          VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_MpsAdjDemand_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_MpsAdjDemand_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_MpsAdjDemand] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [ItemName] ASC, [LocationName] ASC, [YearWw] ASC),
    CONSTRAINT [FK_MpsAdjDemand_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

