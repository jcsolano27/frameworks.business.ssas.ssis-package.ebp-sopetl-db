CREATE TABLE [dbo].[EsdVersionsBypass] (
    [SourceVersionId]     INT           NOT NULL,
    [SourceVersionName]   VARCHAR (MAX) NULL,
    [SourceApplication]   VARCHAR (25)  NOT NULL,
    [SourceApplicationId] INT           NOT NULL,
    [Division]            VARCHAR (25)  NULL,
    [CreatedOn]           DATETIME      CONSTRAINT [DF_EsdVersionsBypass_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25)  CONSTRAINT [DF_EsdVersionsBypass_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdVersionsBypass] PRIMARY KEY CLUSTERED ([SourceVersionId] ASC, [SourceApplicationId] ASC) WITH (FILLFACTOR = 80)
);

