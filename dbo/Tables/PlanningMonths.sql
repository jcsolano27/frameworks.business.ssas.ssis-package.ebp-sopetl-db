CREATE TABLE [dbo].[PlanningMonths] (
    [PlanningMonth]            INT          NOT NULL,
    [PlanningMonthId]          INT          NOT NULL,
    [PlanningMonthDisplayName] VARCHAR (50) NOT NULL,
    [DemandWw]                 INT          NULL,
    [StrategyWw]               INT          NULL,
    [ResetWw]                  INT          NULL,
    [ReconWw]                  INT          NULL,
    [CreatedOn]                DATETIME     CONSTRAINT [DF_EsdReconMonths_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                VARCHAR (25) CONSTRAINT [DF_EsdReconMonths_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_PlanningMonths] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IdxPlanningMonthsPlanningMonth]
    ON [dbo].[PlanningMonths]([PlanningMonth] ASC);

