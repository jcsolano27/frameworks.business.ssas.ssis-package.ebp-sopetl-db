CREATE TABLE [sop].[PlanningFigure] (
    [PlanningMonthNbr] INT              NOT NULL,
    [PlanVersionId]    INT              CONSTRAINT [DF_PlanningFigure_ScenarioId] DEFAULT ((0)) NOT NULL,
    [CorridorId]       INT              CONSTRAINT [DF_PlanningFigure_CorridorId] DEFAULT ((0)) NOT NULL,
    [ProductId]        INT              CONSTRAINT [DF_PlanningFigure_ProductId] DEFAULT ((0)) NOT NULL,
    [ProfitCenterCd]   INT              CONSTRAINT [DF_PlanningFigure_ProfitCenterCd] DEFAULT ((0)) NOT NULL,
    [CustomerId]       INT              CONSTRAINT [DF_PlanningFigure_CustomerId] DEFAULT ((0)) NOT NULL,
    [KeyFigureId]      INT              NOT NULL,
    [TimePeriodId]     INT              NOT NULL,
    [Quantity]         DECIMAL (38, 10) NULL,
    [CreatedOnDtm]     DATETIME         CONSTRAINT [DF_PlanningFigure_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      VARCHAR (25)     CONSTRAINT [DF_PlanningFigure_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME         CONSTRAINT [DF_PlanningFigure_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     VARCHAR (25)     CONSTRAINT [DF_PlanningFigure_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_PlanningFigure] PRIMARY KEY CLUSTERED ([PlanningMonthNbr] ASC, [PlanVersionId] ASC, [CorridorId] ASC, [ProductId] ASC, [ProfitCenterCd] ASC, [CustomerId] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC),
    CONSTRAINT [FK_PlanningFigure_Corridor] FOREIGN KEY ([CorridorId]) REFERENCES [sop].[Corridor] ([CorridorId]),
    CONSTRAINT [FK_PlanningFigure_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [sop].[Customer] ([CustomerId]),
    CONSTRAINT [FK_PlanningFigure_KeyFigure] FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    CONSTRAINT [FK_PlanningFigure_PlanVersion] FOREIGN KEY ([PlanVersionId]) REFERENCES [sop].[PlanVersion] ([PlanVersionId]),
    CONSTRAINT [FK_PlanningFigure_Product] FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId]),
    CONSTRAINT [FK_PlanningFigure_ProfitCenter] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [sop].[ProfitCenter] ([ProfitCenterCd]),
    CONSTRAINT [FK_PlanningFigure_TimePeriod] FOREIGN KEY ([TimePeriodId]) REFERENCES [sop].[TimePeriod] ([TimePeriodId])
);


GO
CREATE NONCLUSTERED INDEX [IdxPlanningFigureKeyFigureId]
    ON [sop].[PlanningFigure]([KeyFigureId] ASC);

