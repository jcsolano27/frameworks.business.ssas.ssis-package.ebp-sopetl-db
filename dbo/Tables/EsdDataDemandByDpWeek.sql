CREATE TABLE [dbo].[EsdDataDemandByDpWeek] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearWw]              INT          NOT NULL,
    [Demand]              FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_EsdDataDemandByDpWeek_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_EsdDataDemandByDpWeek_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdDataDemandByDpWeek] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC)
);

