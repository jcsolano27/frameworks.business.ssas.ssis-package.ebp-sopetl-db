CREATE TABLE [sop].[Capacity] (
    [PlanningMonthNbr] INT              NOT NULL,
    [PlanVersionId]    INT              NOT NULL,
    [CorridorId]       INT              NOT NULL,
    [KeyFigureId]      INT              NOT NULL,
    [TimePeriodId]     INT              NOT NULL,
    [Quantity]         DECIMAL (38, 10) NULL,
    [SourceSystemId]   INT              DEFAULT ([sop].[CONST_SourceSystemId_Svd]()) NOT NULL,
    [CreatedOnDtm]     DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      [sysname]        DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME         DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     [sysname]        DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK__Capacity__2B038C0DC1DB43C8] PRIMARY KEY CLUSTERED ([PlanningMonthNbr] ASC, [PlanVersionId] ASC, [CorridorId] ASC, [KeyFigureId] ASC, [TimePeriodId] ASC, [SourceSystemId] ASC),
    FOREIGN KEY ([CorridorId]) REFERENCES [sop].[Corridor] ([CorridorId]),
    FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    FOREIGN KEY ([PlanVersionId]) REFERENCES [sop].[PlanVersion] ([PlanVersionId]),
    FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId]),
    CONSTRAINT [FK__Capacity__TimePe__6D83CAEE] FOREIGN KEY ([TimePeriodId]) REFERENCES [sop].[TimePeriod] ([TimePeriodId])
);

