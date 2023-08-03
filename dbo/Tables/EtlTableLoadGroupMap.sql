CREATE TABLE [dbo].[EtlTableLoadGroupMap] (
    [TableLoadGroupId] INT           NOT NULL,
    [TableId]          INT           NOT NULL,
    [CreatedOn]        DATETIME2 (7) CONSTRAINT [DF_RefTableLoadGroupMap_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]        VARCHAR (25)  CONSTRAINT [DF_RefTableLoadGroupMap_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_RefTableLoadGroupMap] PRIMARY KEY CLUSTERED ([TableLoadGroupId] ASC, [TableId] ASC),
    CONSTRAINT [FK_TableLoadGroupMap_TableId] FOREIGN KEY ([TableId]) REFERENCES [dbo].[EtlTables] ([TableId]),
    CONSTRAINT [FK_TableLoadGroupMap_TableLoadGroupId] FOREIGN KEY ([TableLoadGroupId]) REFERENCES [dbo].[EtlTableLoadGroups] ([TableLoadGroupId])
);

