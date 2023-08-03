CREATE TABLE [dbo].[EtlBatchRuns] (
    [BatchRunId]          INT            IDENTITY (1, 1) NOT NULL,
    [CreatedOn]           DATETIME2 (2)  CONSTRAINT [DF_BatchRun_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [UpdatedOn]           DATETIME2 (2)  NULL,
    [CreatedBy]           VARCHAR (120)  CONSTRAINT [DF_BatchRun_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [UpdatedBy]           VARCHAR (120)  NULL,
    [HostName]            VARCHAR (100)  CONSTRAINT [DF_BatchRun_HostName] DEFAULT (host_name()) NOT NULL,
    [SourceApplicationId] INT            NOT NULL,
    [LoadParameters]      VARCHAR (100)  NOT NULL,
    [ParameterList]       VARCHAR (1000) NOT NULL,
    [BatchRunStatusId]    TINYINT        NOT NULL,
    [BatchStartedOn]      DATETIME2 (2)  NULL,
    [BatchCompletedOn]    DATETIME2 (2)  NULL,
    [TableList]           VARCHAR (MAX)  NOT NULL,
    [Exception]           VARCHAR (MAX)  NULL,
    [TestFlag]            TINYINT        NULL,
    CONSTRAINT [PK_BatchRun] PRIMARY KEY CLUSTERED ([BatchRunId] ASC),
    CONSTRAINT [FK_BatchRun_BatchRunStatusId] FOREIGN KEY ([BatchRunStatusId]) REFERENCES [dbo].[EtlBatchRunStatus] ([BatchRunStatusId])
);

