CREATE TABLE [sop].[TmgfDemand] (
    [PlanningMonthNbr] INT              NOT NULL,
    [PlanVersionId]    INT              NOT NULL,
    [ProductId]        INT              CONSTRAINT [DF_TmgfDemand_ProductId] DEFAULT ((0)) NOT NULL,
    [ProfitCenterCd]   INT              CONSTRAINT [DF_TmgfDemand_ProfitCenterCd] DEFAULT ((0)) NOT NULL,
    [KeyFigureId]      INT              NOT NULL,
    [TimePeriodId]     INT              NOT NULL,
    [Quantity]         DECIMAL (38, 10) NULL,
    [SourceSystemId]   INT              NULL,
    [CreatedOnDtm]     DATETIME         CONSTRAINT [DF_TmgfDemand_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      VARCHAR (25)     CONSTRAINT [DF_TmgfDemand_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME         CONSTRAINT [DF_TmgfDemand_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     VARCHAR (25)     CONSTRAINT [DF_TmgfDemand_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_TmgfDemand] PRIMARY KEY CLUSTERED ([PlanningMonthNbr] ASC, [PlanVersionId] ASC, [ProductId] ASC, [ProfitCenterCd] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC),
    CONSTRAINT [FK_TmgfDemand_KeyFigure] FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    CONSTRAINT [FK_TmgfDemand_PlanVersion] FOREIGN KEY ([PlanVersionId]) REFERENCES [sop].[PlanVersion] ([PlanVersionId]),
    CONSTRAINT [FK_TmgfDemand_Product] FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId]),
    CONSTRAINT [FK_TmgfDemand_ProfitCenter] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [sop].[ProfitCenter] ([ProfitCenterCd]),
    CONSTRAINT [FK_TmgfDemand_TimePeriod] FOREIGN KEY ([TimePeriodId]) REFERENCES [sop].[TimePeriod] ([TimePeriodId])
);

