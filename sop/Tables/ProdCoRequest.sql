CREATE TABLE [sop].[ProdCoRequest] (
    [PlanVersionId]  INT              NOT NULL,
    [ProductId]      INT              NOT NULL,
    [ProfitCenterCd] INT              NOT NULL,
    [KeyFigureId]    INT              NOT NULL,
    [TimePeriodId]   INT              NOT NULL,
    [Quantity]       DECIMAL (38, 10) NULL,
    [SourceSystemId] INT              NOT NULL,
    [CreatedOnDtm]   DATETIME         DEFAULT (getdate()) NULL,
    [CreatedByNm]    [sysname]        DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]  DATETIME         DEFAULT (getdate()) NULL,
    [ModifiedByNm]   [sysname]        DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PkProdCoRequest] PRIMARY KEY CLUSTERED ([PlanVersionId] ASC, [ProductId] ASC, [ProfitCenterCd] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC, [SourceSystemId] ASC),
    FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    FOREIGN KEY ([PlanVersionId]) REFERENCES [sop].[PlanVersion] ([PlanVersionId]),
    FOREIGN KEY ([ProfitCenterCd]) REFERENCES [sop].[ProfitCenter] ([ProfitCenterCd]),
    FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId]),
    CONSTRAINT [FK__ProdCoReq__Produ__63A55AF9] FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId]),
    CONSTRAINT [FK__ProdCoReq__TimeP__6681C7A4] FOREIGN KEY ([TimePeriodId]) REFERENCES [sop].[TimePeriod] ([TimePeriodId])
);

