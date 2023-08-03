CREATE TABLE [sop].[TableLoadStatus] (
    [TableLoadStatusId]   INT            IDENTITY (1, 1) NOT NULL,
    [TableId]             INT            NOT NULL,
    [WorkingTableName]    VARCHAR (256)  NOT NULL,
    [ParameterList]       VARCHAR (1000) NULL,
    [IsLoaded]            BIT            NOT NULL,
    [CreatedOn]           DATETIME2 (7)  CONSTRAINT [DF_TableLoadStatus_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]           VARCHAR (25)   CONSTRAINT [DF_TableLoadStatus_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]           DATETIME2 (7)  NULL,
    [UpdatedBy]           VARCHAR (25)   NULL,
    [BatchRunId]          INT            NOT NULL,
    [RowsLoaded]          INT            NULL,
    [RowsPurged]          INT            NULL,
    [ProcessingStarted]   DATETIME2 (7)  NULL,
    [ProcessingCompleted] DATETIME2 (7)  NULL,
    CONSTRAINT [PK_TableLoadStatus] PRIMARY KEY CLUSTERED ([TableLoadStatusId] ASC),
    CONSTRAINT [FK_TableLoadStatus_TableId] FOREIGN KEY ([TableId]) REFERENCES [sop].[EtlTables] ([TableId])
);

