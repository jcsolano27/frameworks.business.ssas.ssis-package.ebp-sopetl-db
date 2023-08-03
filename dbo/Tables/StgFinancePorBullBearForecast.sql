CREATE TABLE [dbo].[StgFinancePorBullBearForecast] (
    [CycleNm]                   VARCHAR (4)   NOT NULL,
    [ScenarioNm]                VARCHAR (50)  NULL,
    [VersionNm]                 VARCHAR (50)  NOT NULL,
    [ProfitCenterCd]            INT           NOT NULL,
    [SnOPComputeArchitectureNm] VARCHAR (100) NULL,
    [SnOPProcessNodeNm]         VARCHAR (100) NULL,
    [YearQq]                    INT           NOT NULL,
    [Quantity]                  FLOAT (53)    NULL,
    [ModifiedOn]                DATETIME      NULL,
    [CreatedOn]                 DATETIME      DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                 VARCHAR (25)  DEFAULT (original_login()) NOT NULL
);

