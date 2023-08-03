CREATE TABLE [sop].[StgConsensusDemandForecast] (
    [SourceSystemId]             INT              CONSTRAINT [DF_StgConsensusDemandForecast_SourceApplicationId] DEFAULT ((1)) NULL,
    [FiscalCalendarId]           INT              NULL,
    [ProductNodeId]              INT              NULL,
    [ProfitCenterHierarchyId]    INT              NULL,
    [VersionId]                  INT              NULL,
    [ScenarioId]                 INT              NULL,
    [ConsensusDmdFcstAmtPublish] DECIMAL (38, 10) NULL,
    [CreatedOn]                  DATETIME         CONSTRAINT [DF_StgConsensusDemandForecast_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]                  NVARCHAR (25)    CONSTRAINT [DF_StgConsensusDemandForecast_Createdby] DEFAULT (original_login()) NOT NULL
);

