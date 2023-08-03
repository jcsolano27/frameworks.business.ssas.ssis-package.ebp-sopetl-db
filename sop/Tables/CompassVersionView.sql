CREATE TABLE [sop].[CompassVersionView] (
    [CompassVersionViewId] INT            IDENTITY (1, 1) NOT NULL,
    [VersionId]            INT            NOT NULL,
    [PublishLogId]         INT            NOT NULL,
    [LrpCycleYearNbr]      INT            NULL,
    [LrpCycleQuarterNbr]   INT            NULL,
    [ScenarioId]           INT            NULL,
    [ProfileId]            INT            NULL,
    [ScenarioNm]           NVARCHAR (255) NULL,
    [ProfileDsc]           NVARCHAR (255) NULL,
    [VersionDsc]           NVARCHAR (255) NULL,
    [IsPorCd]              NVARCHAR (1)   NULL,
    [PublishStatusCd]      NVARCHAR (25)  NULL,
    [StartTs]              DATETIME       NULL,
    [EndTs]                DATETIME       NULL,
    [LoadedToHanaTs]       DATETIME       NULL,
    [CreatedOn]            DATETIME       DEFAULT (getdate()) NULL,
    [CreatedBy]            NVARCHAR (25)  DEFAULT (original_login()) NULL,
    [ModifiedOn]           DATETIME       DEFAULT (getdate()) NULL,
    [ModifiedBy]           NVARCHAR (25)  DEFAULT (original_login()) NULL,
    PRIMARY KEY CLUSTERED ([CompassVersionViewId] ASC)
);

