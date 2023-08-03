CREATE TABLE [sop].[MfgSupplyForecast] (
    [PlanningMonthNbr] INT              NOT NULL,
    [PlanVersionId]    INT              NOT NULL,
    [CorridorId]       INT              NOT NULL,
    [ProductId]        INT              NOT NULL,
    [ProfitCenterCd]   INT              NOT NULL,
    [CustomerId]       INT              NOT NULL,
    [KeyFigureId]      INT              NOT NULL,
    [TimePeriodId]     INT              NOT NULL,
    [Quantity]         DECIMAL (38, 10) NULL,
    [CreatedOnDtm]     DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      VARCHAR (25)     DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME         DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     VARCHAR (25)     DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_MgfSupplyForecast] PRIMARY KEY CLUSTERED ([PlanningMonthNbr] ASC, [PlanVersionId] ASC, [CorridorId] ASC, [ProductId] ASC, [ProfitCenterCd] ASC, [CustomerId] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC)
);

