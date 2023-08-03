CREATE TABLE [dbo].[SnOPDemandProductWoiTarget] (
    [PlanningMonth]          INT          NOT NULL,
    [SourceApplicationId]    INT          NOT NULL,
    [SvdSourceApplicationId] INT          NOT NULL,
    [SourceVersionId]        INT          NOT NULL,
    [SnOPDemandProductId]    INT          NOT NULL,
    [YearWw]                 INT          NOT NULL,
    [Quantity]               FLOAT (53)   NULL,
    [CreatedOn]              DATETIME     CONSTRAINT [DF_SnOPDemandProductWoiTarget_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25) CONSTRAINT [DF_SnOPDemandProductWoiTarget_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SnOPDemandProductWoiTarget] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SourceApplicationId] ASC, [SvdSourceApplicationId] ASC, [SourceVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_SnOPDemandProductWoiTarget_001]
    ON [dbo].[SnOPDemandProductWoiTarget]([SvdSourceApplicationId] ASC, [SnOPDemandProductId] ASC, [PlanningMonth] ASC)
    INCLUDE([Quantity]);


GO
CREATE NONCLUSTERED INDEX [IX_SnOPDemandProductWoiTarget_002]
    ON [dbo].[SnOPDemandProductWoiTarget]([PlanningMonth] ASC, [SvdSourceApplicationId] ASC, [SourceVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC)
    INCLUDE([Quantity]);

