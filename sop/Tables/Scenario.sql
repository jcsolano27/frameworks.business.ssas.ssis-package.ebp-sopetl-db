CREATE TABLE [sop].[Scenario] (
    [ScenarioId]       INT           NOT NULL,
    [ScenarioNm]       VARCHAR (50)  NOT NULL,
    [ScenarioDsc]      VARCHAR (100) NULL,
    [SourceScenarioId] INT           NOT NULL,
    [ActiveInd]        BIT           CONSTRAINT [DF_Scenario_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId]   INT           NOT NULL,
    [CreatedOnDtm]     DATETIME      CONSTRAINT [DF_Scenario_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      VARCHAR (25)  CONSTRAINT [DF_Scenario_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME      CONSTRAINT [DF_Scenario_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     VARCHAR (25)  CONSTRAINT [DF_Scenario_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_Scenario] PRIMARY KEY CLUSTERED ([ScenarioId] ASC),
    CONSTRAINT [FK_Scenario_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_Scenario_ScenarioNm]
    ON [sop].[Scenario]([ScenarioNm] ASC);

