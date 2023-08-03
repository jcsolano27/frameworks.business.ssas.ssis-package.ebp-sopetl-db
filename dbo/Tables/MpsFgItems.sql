CREATE TABLE [dbo].[MpsFgItems] (
    [EsdVersionId]          INT          NOT NULL,
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [SourceVersionId]       INT          NOT NULL,
    [SolveGroupName]        VARCHAR (50) NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_MpsFgItems_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_MpsFgItems_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_MpsFgItems] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [ItemName] ASC),
    CONSTRAINT [FK_MpsFgItems_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

