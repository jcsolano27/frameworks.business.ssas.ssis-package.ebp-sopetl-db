﻿CREATE TABLE [dbo].[EsdDataBonusableSupplyProfitCenterDistribution] (
    [YearQq]                     INT           NOT NULL,
    [YearMm]                     INT           NULL,
    [ResetWw]                    INT           NOT NULL,
    [VersionFiscalCalendarId]    INT           NULL,
    [FiscalCalendarId]           INT           NULL,
    [EsdVersionId]               INT           NOT NULL,
    [SourceVersionId]            INT           NOT NULL,
    [SvdSourceVersionId]         INT           NOT NULL,
    [ProfitCenterCd]             INT           NOT NULL,
    [ProfitCenterHierarchyId]    INT           NULL,
    [SnOPDemandProductId]        INT           NOT NULL,
    [SourceApplicationName]      VARCHAR (25)  NOT NULL,
    [ItemName]                   VARCHAR (50)  NOT NULL,
    [ItemClass]                  VARCHAR (25)  NULL,
    [ItemDescription]            VARCHAR (100) NULL,
    [SdaFamily]                  VARCHAR (50)  NULL,
    [SuperGroupNm]               VARCHAR (100) NULL,
    [WhatIfScenarioName]         VARCHAR (50)  NOT NULL,
    [Comments]                   VARCHAR (MAX) NULL,
    [Process]                    VARCHAR (50)  NULL,
    [TypeData]                   VARCHAR (25)  NOT NULL,
    [BonusableDiscreteExcess]    FLOAT (53)    NULL,
    [BonusPercent]               FLOAT (53)    NULL,
    [ExcessToMpsInvTargetCum]    FLOAT (53)    NULL,
    [NonBonusableCum]            FLOAT (53)    NULL,
    [NonBonusableDiscreteExcess] FLOAT (53)    NULL,
    [ProfitCenterPct]            FLOAT (53)    NULL
);

