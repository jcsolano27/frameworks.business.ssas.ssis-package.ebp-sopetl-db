CREATE TABLE [dbo].[StgEsdBonusableSupply] (
    [EsdVersionId]            INT           NOT NULL,
    [SourceApplicationName]   VARCHAR (25)  NOT NULL,
    [SourceVersionId]         INT           NOT NULL,
    [ResetWw]                 INT           NOT NULL,
    [WhatIfScenarioName]      VARCHAR (50)  NULL,
    [SdaFamily]               VARCHAR (50)  NULL,
    [ItemName]                VARCHAR (50)  NULL,
    [ItemClass]               VARCHAR (25)  NULL,
    [ItemDescription]         VARCHAR (100) NULL,
    [SnOPDemandProductNm]     VARCHAR (100) NULL,
    [BonusPercent]            FLOAT (53)    NULL,
    [Comments]                VARCHAR (MAX) NULL,
    [YearQq]                  INT           NULL,
    [ExcessToMpsInvTargetCum] FLOAT (53)    NULL,
    [CreatedOn]               DATETIME      CONSTRAINT [DF_StgEsdDataBonusableSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]               VARCHAR (25)  CONSTRAINT [DF_StgEsdDataBonusableSupply_CreatedBy] DEFAULT (original_login()) NOT NULL
);

