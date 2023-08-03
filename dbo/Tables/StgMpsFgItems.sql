CREATE TABLE [dbo].[StgMpsFgItems] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationName] VARCHAR (25)  NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [SolveGroupName]        VARCHAR (100) NULL,
    [ItemName]              VARCHAR (50)  NOT NULL,
    [CreatedOn]             DATETIME      CONSTRAINT [DF_StgMpsFgItems_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25)  CONSTRAINT [DF_StgMpsFgItems_CreatedBy] DEFAULT (user_name()) NOT NULL
);

