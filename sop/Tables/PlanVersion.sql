CREATE TABLE [sop].[PlanVersion] (
    [PlanVersionId]          INT           IDENTITY (1, 1) NOT NULL,
    [PlanVersionNm]          VARCHAR (50)  NOT NULL,
    [PlanVersionDsc]         VARCHAR (100) NULL,
    [PlanVersionCategoryCd]  CHAR (3)      NULL,
    [ScenarioId]             INT           NOT NULL,
    [ConstraintCategoryId]   INT           CONSTRAINT [DF_PlanVersion_ConstraintCategoryId] DEFAULT ((0)) NOT NULL,
    [SourceVersionId]        INT           NULL,
    [SourcePlanningMonthNbr] INT           NULL,
    [ActiveInd]              BIT           CONSTRAINT [DF_PlanVersion_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId]         INT           NOT NULL,
    [CreatedOnDtm]           DATETIME      CONSTRAINT [DF_PlanVersion_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]            VARCHAR (25)  CONSTRAINT [DF_PlanVersion_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]          DATETIME      CONSTRAINT [DF_PlanVersion_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]           VARCHAR (25)  CONSTRAINT [DF_PlanVersion_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_PlanVersion] PRIMARY KEY CLUSTERED ([PlanVersionId] ASC),
    CONSTRAINT [FK_PlanVersion_ConstraintCategory] FOREIGN KEY ([ConstraintCategoryId]) REFERENCES [sop].[ConstraintCategory] ([ConstraintCategoryId]),
    CONSTRAINT [FK_PlanVersion_Scenario] FOREIGN KEY ([ScenarioId]) REFERENCES [sop].[Scenario] ([ScenarioId]),
    CONSTRAINT [FK_PlanVersion_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);

