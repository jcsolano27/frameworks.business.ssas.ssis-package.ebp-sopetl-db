﻿CREATE TABLE [dbo].[EsdTotalSupplyAndDemandByDpWeekBkp] (
    [SourceApplicationName]                        VARCHAR (25) NULL,
    [EsdVersionId]                                 INT          NOT NULL,
    [SnOPDemandProductId]                          INT          NOT NULL,
    [YearWw]                                       INT          NOT NULL,
    [TotalSupply]                                  FLOAT (53)   NULL,
    [UnrestrictedBoh]                              FLOAT (53)   NULL,
    [SellableBoh]                                  FLOAT (53)   NULL,
    [MpsSellableSupply]                            FLOAT (53)   NULL,
    [AdjSellableSupply]                            FLOAT (53)   NULL,
    [BonusableDiscreteExcess]                      FLOAT (53)   NULL,
    [MPSSellableSupplyWithBonusableDiscreteExcess] FLOAT (53)   NULL,
    [SellableSupply]                               FLOAT (53)   NULL,
    [DiscreteEohExcess]                            FLOAT (53)   NULL,
    [ExcessAdjust]                                 FLOAT (53)   NULL,
    [NonBonusableCum]                              FLOAT (53)   NULL,
    [NonBonusableDiscreteExcess]                   FLOAT (53)   NULL,
    [DiscreteExcessForTotalSupply]                 FLOAT (53)   NULL,
    [Demand]                                       FLOAT (53)   NULL,
    [AdjDemand]                                    FLOAT (53)   NULL,
    [DemandWithAdj]                                FLOAT (53)   NULL,
    [FinalSellableEoh]                             FLOAT (53)   NULL,
    [FinalSellableWoi]                             FLOAT (53)   NULL,
    [AdjAtmConstrainedSupply]                      FLOAT (53)   NULL,
    [FinalUnrestrictedEoh]                         FLOAT (53)   NULL,
    [CreatedOn]                                    DATETIME     NOT NULL,
    [CreatedBy]                                    VARCHAR (25) NOT NULL
);
