CREATE TABLE [dbo].[EtlTableLoadGroups] (
    [TableLoadGroupId]   INT            NOT NULL,
    [TableLoadGroupName] VARCHAR (50)   NOT NULL,
    [GroupType]          VARCHAR (10)   NOT NULL,
    [Description]        VARCHAR (1000) NULL,
    [CreatedOn]          DATETIME       CONSTRAINT [DF_RefTableLoadGroup_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]          VARCHAR (25)   CONSTRAINT [DF_RefTableLoadGroup_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_RefTableLoadGroup] PRIMARY KEY CLUSTERED ([TableLoadGroupId] ASC)
);

