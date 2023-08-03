CREATE TABLE [sop].[TableLoadStatusHistory] (
    [TableLoadStatusHistoryId] INT            IDENTITY (1, 1) NOT NULL,
    [TableLoadStatusId]        INT            NOT NULL,
    [TableId]                  INT            NOT NULL,
    [WorkingTableName]         VARCHAR (256)  NOT NULL,
    [ParameterList]            VARCHAR (1000) NULL,
    [IsLoaded]                 BIT            NOT NULL,
    [CreatedOn]                DATETIME2 (7)  NOT NULL,
    [CreatedBy]                VARCHAR (25)   NOT NULL,
    [UpdatedOn]                DATETIME2 (7)  NULL,
    [UpdatedBy]                VARCHAR (25)   NULL,
    [BatchRunId]               INT            NOT NULL,
    [RowsLoaded]               INT            NULL,
    [RowsPurged]               INT            NULL,
    [ProcessingStarted]        DATETIME2 (7)  NULL,
    [ProcessingCompleted]      DATETIME2 (7)  NULL,
    CONSTRAINT [PK_TableLoadStatusHistory] PRIMARY KEY CLUSTERED ([TableLoadStatusHistoryId] ASC)
);

