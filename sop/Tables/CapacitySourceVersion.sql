CREATE TABLE [sop].[CapacitySourceVersion] (
    [VersionId]          INT            NULL,
    [PublishLogId]       INT            NULL,
    [LrpCycleYearNbr]    INT            NULL,
    [LrpCycleQuarterNbr] INT            NULL,
    [ScenarioId]         INT            NULL,
    [ProfileId]          INT            NULL,
    [ScenarioNm]         NVARCHAR (255) NULL,
    [ProfileDsc]         NVARCHAR (255) NULL,
    [VersionDsc]         NVARCHAR (255) NULL,
    [IsPorCd]            NVARCHAR (1)   NULL,
    [PublishStatusCd]    NVARCHAR (25)  NULL,
    [StartTs]            DATETIME       NULL,
    [EndTs]              DATETIME       NULL,
    [CreatedOnTs]        DATETIME       NULL,
    [CreatedBy]          NVARCHAR (25)  NULL,
    [LoadedToHanaTs]     DATETIME       NULL,
    [ModifiedOnDtm]      DATETIME       DEFAULT (getdate()) NULL,
    [ModifiedByNm]       [sysname]      DEFAULT (original_login()) NOT NULL
);

