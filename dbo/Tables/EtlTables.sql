CREATE TABLE [dbo].[EtlTables] (
    [TableId]             INT            NOT NULL,
    [TableName]           VARCHAR (100)  NOT NULL,
    [SourceApplicationId] INT            NOT NULL,
    [LoadParameters]      VARCHAR (100)  NOT NULL,
    [Description]         VARCHAR (1000) NULL,
    [Keywords]            VARCHAR (200)  NULL,
    [Active]              BIT            NOT NULL,
    [CreatedOn]           DATETIME2 (7)  CONSTRAINT [DF_RefTable_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]           VARCHAR (25)   CONSTRAINT [DF_RefTable_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]           DATETIME2 (7)  NULL,
    [UpdatedBy]           VARCHAR (25)   NULL,
    [PurgeScript]         NVARCHAR (MAX) CONSTRAINT [DF_RefTable_PurgeScript] DEFAULT (N'--NoPurge') NOT NULL,
    [PackageName]         VARCHAR (100)  NULL,
    [StagingTables]       VARCHAR (8000) NULL,
    CONSTRAINT [PK_RefTable] PRIMARY KEY CLUSTERED ([TableId] ASC)
);

