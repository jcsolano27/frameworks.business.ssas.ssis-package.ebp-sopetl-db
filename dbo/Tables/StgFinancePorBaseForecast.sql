CREATE TABLE [dbo].[StgFinancePorBaseForecast] (
    [CycleNm]             VARCHAR (4)  NOT NULL,
    [ScenarioNm]          VARCHAR (10) NULL,
    [VersionNm]           VARCHAR (50) NOT NULL,
    [SnOPSupplyProductId] INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [YearQq]              INT          NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [ModifiedOn]          DATETIME     NULL,
    [CreatedOn]           DATETIME     DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) DEFAULT (original_login()) NOT NULL
);

