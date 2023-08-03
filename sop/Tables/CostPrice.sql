CREATE TABLE [sop].[CostPrice] (
    [KeyFigureId]     INT          NOT NULL,
    [ProductId]       INT          NOT NULL,
    [SourceProductId] VARCHAR (30) NOT NULL,
    [PlanningMonth]   INT          DEFAULT ([dbo].[CONST_PlanningMonth]()) NULL,
    [TimePeriodId]    INT          NOT NULL,
    [KeyFigureValue]  FLOAT (53)   NULL,
    [CreatedOn]       DATETIME     DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25) DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]      DATETIME     DEFAULT (getdate()) NOT NULL,
    [ModifiedBy]      VARCHAR (25) DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_CostPrice] PRIMARY KEY CLUSTERED ([KeyFigureId] ASC, [ProductId] ASC, [TimePeriodId] ASC),
    CONSTRAINT [FK_CostPrice_KeyFigureId] FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    CONSTRAINT [FK_CostPrice_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId])
);

