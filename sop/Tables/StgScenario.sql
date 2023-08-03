CREATE TABLE [sop].[StgScenario] (
    [SourceApplicationId] INT           CONSTRAINT [DF_StgScenario_SourceApplicationId] DEFAULT ((2)) NULL,
    [ScenarioId]          INT           NULL,
    [HierarchyLevelId]    INT           NULL,
    [AllScenarioId]       INT           NULL,
    [AllScenarioNm]       NVARCHAR (25) NOT NULL,
    [ScenarioNm]          NVARCHAR (25) NOT NULL,
    [IBPScenarioNm]       NVARCHAR (25) NOT NULL,
    [IBPScenarioId]       NVARCHAR (50) NOT NULL,
    [ScenarioTypeCd]      NVARCHAR (25) NOT NULL,
    [ActiveInd]           NCHAR (1)     NULL,
    [CreatedOn]           DATETIME      CONSTRAINT [DF_StgScenario_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]           NVARCHAR (25) CONSTRAINT [DF_StgScenario_Createdby] DEFAULT (original_login()) NOT NULL
);

