CREATE TABLE [dbo].[MpsBoh] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [ItemClass]             VARCHAR (10)  NOT NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [ItemDescription]       VARCHAR (100) NULL,
    [LocationName]          VARCHAR (25)  NOT NULL,
    [YearWw]                INT           NOT NULL,
    [Quantity]              FLOAT (53)    NULL,
    [CreatedOn]             DATETIME      CONSTRAINT [DF_EsdDataBoh_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25)  CONSTRAINT [DF_EsdDataBoh_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdDataBoh] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [ItemName] ASC, [LocationName] ASC, [YearWw] ASC),
    CONSTRAINT [FK_EsdDataBoh_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

