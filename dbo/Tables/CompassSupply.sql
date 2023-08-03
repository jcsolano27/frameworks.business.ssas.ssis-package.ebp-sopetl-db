CREATE TABLE [dbo].[CompassSupply] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPSupplyProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Supply]                FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_CompassSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_CompassSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_CompassSupply] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPSupplyProductId] ASC, [YearWw] ASC),
    CONSTRAINT [FK_CompassSupply_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

