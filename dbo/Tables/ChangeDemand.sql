CREATE TABLE [dbo].[ChangeDemand] (
    [PrimaryKey]              INT           IDENTITY (1, 1) NOT NULL,
    [SnOPDemandForecastMonth] INT           NOT NULL,
    [SnOPDemandProductId]     INT           NOT NULL,
    [SnOPDemandProductNm]     VARCHAR (100) NULL,
    [YearQtr]                 INT           NOT NULL,
    [Demand]                  FLOAT (53)    NULL,
    [NewDemand]               FLOAT (53)    NULL,
    [Change]                  VARCHAR (2)   DEFAULT ('Y') NULL,
    [ChangeType]              VARCHAR (100) NULL,
    [ImpactIntelGoals]        VARCHAR (100) NULL,
    [Concatenated]            VARCHAR (300) NULL,
    [ModifiedOn]              DATETIME      CONSTRAINT [DF_ChangeDemand_ModifiedOn] DEFAULT (getdate()) NULL,
    [CreatedBy]               VARCHAR (100) CONSTRAINT [DF_ChangeDemand_CreatedBy] DEFAULT (user_name()) NULL,
    PRIMARY KEY CLUSTERED ([PrimaryKey] ASC)
);

