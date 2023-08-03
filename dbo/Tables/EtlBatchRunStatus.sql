CREATE TABLE [dbo].[EtlBatchRunStatus] (
    [BatchRunStatusId] TINYINT      NOT NULL,
    [StatusName]       VARCHAR (50) NOT NULL,
    CONSTRAINT [PK_RefBatchRunStatus] PRIMARY KEY CLUSTERED ([BatchRunStatusId] ASC)
);

