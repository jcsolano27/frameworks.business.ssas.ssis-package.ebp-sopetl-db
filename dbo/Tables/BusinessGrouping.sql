CREATE TABLE [dbo].[BusinessGrouping] (
    [BusinessGroupingId]        INT           IDENTITY (0, 1) NOT NULL,
    [SnOPComputeArchitectureNm] VARCHAR (100) NOT NULL,
    [SnOPProcessNodeNm]         VARCHAR (100) NOT NULL,
    [CreatedOn]                 DATETIME      DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                 VARCHAR (25)  DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([BusinessGroupingId] ASC)
);

