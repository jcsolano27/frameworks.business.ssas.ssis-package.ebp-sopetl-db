CREATE TABLE [dbo].[CompassEohWithoutExcess] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [CompassPublishLogId]   INT          NOT NULL,
    [CompassRunId]          INT          NOT NULL,
    [SnOPDemandProductId]   INT          NOT NULL,
    [YearWw]                INT          NOT NULL,
    [EohWithoutExcess]      FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_CompassEohWithoutExcess_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_CompassEohWithoutExcess_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_CompassEohWithoutExcess] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC),
    CONSTRAINT [FK_CompassEohWithoutExcess_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

