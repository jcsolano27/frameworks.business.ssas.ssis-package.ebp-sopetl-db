CREATE TABLE [dbo].[CompassDieEsuExcess] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [CompassPublishLogId]   INT           NOT NULL,
    [CompassRunId]          INT           NOT NULL,
    [ItemId]                VARCHAR (100) NOT NULL,
    [YearWw]                INT           NOT NULL,
    [DieEsuExcess]          FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      CONSTRAINT [DF_CompassDieEsuExcess_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25)  CONSTRAINT [DF_CompassDieEsuExcess_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_CompassDieEsuExcess] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [ItemId] ASC, [YearWw] ASC),
    CONSTRAINT [FK_CompassDieEsuExcess_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

