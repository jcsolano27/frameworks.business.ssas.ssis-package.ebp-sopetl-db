CREATE TABLE [dbo].[CompassEoh] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Eoh]                   FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_CompassEoh_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_CompassEoh_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_CompassEoh] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC),
    CONSTRAINT [FK_CompassEoh_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

