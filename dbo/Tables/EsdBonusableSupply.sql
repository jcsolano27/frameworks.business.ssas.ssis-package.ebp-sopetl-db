CREATE TABLE [dbo].[EsdBonusableSupply] (
    [EsdVersionId]               INT           NOT NULL,
    [SourceApplicationName]      VARCHAR (25)  NOT NULL,
    [SourceVersionId]            INT           NOT NULL,
    [ResetWw]                    INT           NOT NULL,
    [WhatIfScenarioName]         VARCHAR (50)  NOT NULL,
    [SdaFamily]                  VARCHAR (50)  NULL,
    [ItemName]                   VARCHAR (50)  NOT NULL,
    [ItemClass]                  VARCHAR (25)  NULL,
    [ItemDescription]            VARCHAR (100) NULL,
    [SnOPDemandProductId]        INT           NOT NULL,
    [BonusPercent]               FLOAT (53)    NULL,
    [Comments]                   VARCHAR (MAX) NULL,
    [YearQq]                     INT           NOT NULL,
    [ExcessToMpsInvTargetCum]    FLOAT (53)    NULL,
    [Process]                    VARCHAR (50)  NULL,
    [YearMm]                     INT           NULL,
    [BonusableDiscreteExcess]    FLOAT (53)    NULL,
    [NonBonusableDiscreteExcess] FLOAT (53)    NULL,
    [ExcessToMpsInvTarget]       FLOAT (53)    NULL,
    [BonusableCum]               FLOAT (53)    NULL,
    [NonBonusableCum]            FLOAT (53)    NULL,
    [CreatedOn]                  DATETIME      CONSTRAINT [DF_EsdDataBonusableSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                  VARCHAR (25)  CONSTRAINT [DF_EsdDataBonusableSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [VersionFiscalCalendarId]    INT           NULL,
    [FiscalCalendarId]           INT           NULL,
    CONSTRAINT [PK_EsdDataBonusableSupply] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [ItemName] ASC, [SnOPDemandProductId] ASC, [YearQq] ASC),
    CONSTRAINT [FK_EsdDataBonusableSupply_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);


GO
CREATE NONCLUSTERED INDEX [IDX_001_EsdBonusableSupply]
    ON [dbo].[EsdBonusableSupply]([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearQq] ASC);

