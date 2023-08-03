CREATE TABLE [dbo].[StgMpsAdjDemand] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [SourceVersionId]       INT          NOT NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [LocationName]          VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_StgMpsAdjDemand_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_StgMpsAdjDemand_CreatedBy] DEFAULT (user_name()) NOT NULL
);

