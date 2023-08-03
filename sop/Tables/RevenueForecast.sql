CREATE TABLE [sop].[RevenueForecast] (
    [PlanningMonthNbr] INT              NOT NULL,
    [PlanVersionId]    INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_PlanVersion]()) NOT NULL,
    [ProductId]        INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_Product]()) NOT NULL,
    [ProfitCenterCd]   INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_ProfitCenter]()) NOT NULL,
    [KeyFigureId]      INT              NOT NULL,
    [TimePeriodId]     INT              NOT NULL,
    [Quantity]         DECIMAL (38, 10) NULL,
    [SourceSystemId]   INT              DEFAULT ([sop].[CONST_SourceSystemId_SapIbp]()) NOT NULL,
    [CreatedOnDtm]     DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      [sysname]        DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME         DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     [sysname]        DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PkRevenueForecast] PRIMARY KEY CLUSTERED ([PlanningMonthNbr] ASC, [PlanVersionId] ASC, [ProductId] ASC, [ProfitCenterCd] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC, [SourceSystemId] ASC),
    FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    FOREIGN KEY ([PlanVersionId]) REFERENCES [sop].[PlanVersion] ([PlanVersionId]),
    FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId]),
    FOREIGN KEY ([ProfitCenterCd]) REFERENCES [sop].[ProfitCenter] ([ProfitCenterCd]),
    FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId]),
    FOREIGN KEY ([TimePeriodId]) REFERENCES [sop].[TimePeriod] ([TimePeriodId])
);

