﻿CREATE TABLE [dbo].[EsdSupplyByFgWeekSnapshot] (
    [EsdVersionId]       INT          NOT NULL,
    [LastStitchYearWw]   INT          NOT NULL,
    [ItemName]           VARCHAR (50) NOT NULL,
    [YearWw]             INT          NOT NULL,
    [WwId]               INT          NOT NULL,
    [OneWoi]             FLOAT (53)   NULL,
    [TotalAdjWoi]        FLOAT (53)   NULL,
    [UnrestrictedBoh]    FLOAT (53)   NULL,
    [WoiWithoutExcess]   FLOAT (53)   NULL,
    [FgSupplyReqt]       FLOAT (53)   NULL,
    [MrbBonusback]       FLOAT (53)   NULL,
    [OneWoiBoh]          FLOAT (53)   NULL,
    [Eoh]                FLOAT (53)   NULL,
    [BohTarget]          FLOAT (53)   NULL,
    [SellableEoh]        FLOAT (53)   NULL,
    [CalcSellableEoh]    FLOAT (53)   NULL,
    [BohExcess]          FLOAT (53)   NULL,
    [SellableBoh]        FLOAT (53)   NULL,
    [EohExcess]          FLOAT (53)   NULL,
    [DiscreteEohExcess]  FLOAT (53)   NULL,
    [MPSSellableSupply]  FLOAT (53)   NULL,
    [SupplyDelta]        FLOAT (53)   NULL,
    [NewEOH]             FLOAT (53)   NULL,
    [EohInvTgt]          FLOAT (53)   NULL,
    [TestOutActual]      FLOAT (53)   NULL,
    [Billings]           FLOAT (53)   NULL,
    [EohTarget]          FLOAT (53)   NULL,
    [SellableSupply]     FLOAT (53)   NULL,
    [ExcessAdjust]       FLOAT (53)   NULL,
    [Scrapped]           FLOAT (53)   NULL,
    [RMA]                FLOAT (53)   NULL,
    [Rework]             FLOAT (53)   NULL,
    [Blockstock]         FLOAT (53)   NULL,
    [SourceEsdVersionId] FLOAT (53)   NULL,
    [StitchYearWw]       INT          NOT NULL,
    [IsReset]            BIT          NOT NULL,
    [IsMonthRoll]        BIT          NOT NULL,
    [CreatedOn]          DATETIME     CONSTRAINT [DF_EsdDataSupplyStitchSnapshot_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]          VARCHAR (25) CONSTRAINT [DF_EsdDataSupplyStitchSnapshot_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdDataSupplyStitchSnapshot] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [LastStitchYearWw] ASC, [ItemName] ASC, [YearWw] ASC)
);

