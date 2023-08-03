CREATE TABLE [sop].[ActualSales] (
    [PlanVersionId]  INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_PlanVersion]()) NOT NULL,
    [ProductId]      INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_Product]()) NOT NULL,
    [ProfitCenterCd] INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_ProfitCenter]()) NOT NULL,
    [CustomerId]     INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_Customer]()) NOT NULL,
    [KeyFigureId]    INT              NOT NULL,
    [TimePeriodId]   INT              NOT NULL,
    [Quantity]       DECIMAL (38, 10) NULL,
    [SourceSystemId] INT              DEFAULT ([sop].[CONST_NotApplicableIdentifier_SourceSystem]()) NOT NULL,
    [CreatedOnDtm]   DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]    [sysname]        DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]  DATETIME         DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]   [sysname]        DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [Pk_ActualSales] PRIMARY KEY CLUSTERED ([PlanVersionId] ASC, [ProductId] ASC, [ProfitCenterCd] ASC, [CustomerId] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC, [SourceSystemId] ASC),
    FOREIGN KEY ([CustomerId]) REFERENCES [sop].[Customer] ([CustomerId]),
    FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    FOREIGN KEY ([PlanVersionId]) REFERENCES [sop].[PlanVersion] ([PlanVersionId]),
    FOREIGN KEY ([ProfitCenterCd]) REFERENCES [sop].[ProfitCenter] ([ProfitCenterCd]),
    FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId]),
    CONSTRAINT [FK__ActualSal__Produ__086CCB54] FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId]),
    CONSTRAINT [FK__ActualSal__TimeP__0F19C8E3] FOREIGN KEY ([TimePeriodId]) REFERENCES [sop].[TimePeriod] ([TimePeriodId])
);

