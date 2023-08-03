CREATE TABLE [sop].[BatchRun] (
    [BatchRunId]       INT            IDENTITY (1, 1) NOT NULL,
    [HostName]         VARCHAR (100)  CONSTRAINT [DF_BatchRun_HostName] DEFAULT (host_name()) NOT NULL,
    [PackageSystemId]  INT            NOT NULL,
    [LoadParameters]   VARCHAR (100)  NOT NULL,
    [ParameterList]    VARCHAR (1000) NOT NULL,
    [BatchRunStatusId] TINYINT        NOT NULL,
    [BatchStartedOn]   DATETIME2 (2)  NULL,
    [BatchCompletedOn] DATETIME2 (2)  NULL,
    [TableList]        VARCHAR (MAX)  NOT NULL,
    [Exception]        VARCHAR (MAX)  NULL,
    [TestFlag]         TINYINT        NULL,
    [UpdatedOn]        DATETIME2 (2)  NULL,
    [UpdatedBy]        VARCHAR (120)  NULL,
    [CreatedOn]        DATETIME2 (2)  CONSTRAINT [DF_BatchRun_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]        VARCHAR (120)  CONSTRAINT [DF_BatchRun_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_BatchRun] PRIMARY KEY CLUSTERED ([BatchRunId] ASC),
    CONSTRAINT [FK_BatchRun_BatchRunStatusId] FOREIGN KEY ([BatchRunStatusId]) REFERENCES [sop].[BatchRunStatus] ([BatchRunStatusId])
);

