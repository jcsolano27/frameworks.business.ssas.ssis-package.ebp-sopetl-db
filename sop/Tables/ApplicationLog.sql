CREATE TABLE [sop].[ApplicationLog] (
    [ApplicationLogId] INT                IDENTITY (1, 1) NOT FOR REPLICATION NOT NULL,
    [LogDate]          DATETIMEOFFSET (7) NOT NULL,
    [LogSource]        VARCHAR (255)      NOT NULL,
    [LogType]          VARCHAR (255)      NOT NULL,
    [Category]         VARCHAR (1000)     NOT NULL,
    [SubCategory]      VARCHAR (1000)     NULL,
    [Message]          VARCHAR (MAX)      NULL,
    [Status]           VARCHAR (25)       NOT NULL,
    [Exception]        VARCHAR (MAX)      NULL,
    [BatchId]          VARCHAR (1000)     NULL,
    [HostName]         VARCHAR (255)      NOT NULL,
    [CreatedOn]        DATETIME           DEFAULT (getdate()) NOT NULL,
    [CreatedBy]        VARCHAR (25)       DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ApplicationLog] PRIMARY KEY CLUSTERED ([ApplicationLogId] ASC)
);

