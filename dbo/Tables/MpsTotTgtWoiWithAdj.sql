CREATE TABLE [dbo].[MpsTotTgtWoiWithAdj] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (25)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (50)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [TotTgtWoiWithAdj]      FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      CONSTRAINT [DF_EsdDataTotTgtWoiWithAdj_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25)  CONSTRAINT [DF_EsdDataTotTgtWoiWithAdj_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdDataTotTgtWoiWithAdj] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [ItemName] ASC, [LocationName] ASC, [YearWw] ASC),
    CONSTRAINT [FK_EsdDataTotTgtWoiWithAdj_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

