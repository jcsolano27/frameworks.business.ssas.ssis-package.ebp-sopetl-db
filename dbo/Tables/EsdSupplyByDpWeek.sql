CREATE TABLE [dbo].[EsdSupplyByDpWeek] (
    [EsdVersionId]        INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [YearWw]              INT          NOT NULL,
    [UnrestrictedBoh]     FLOAT (53)   NULL,
    [SellableBoh]         FLOAT (53)   NULL,
    [MPSSellableSupply]   FLOAT (53)   NULL,
    [ExcessAdjust]        FLOAT (53)   NULL,
    [SupplyDelta]         FLOAT (53)   NULL,
    [DiscreteEohExcess]   FLOAT (53)   NULL,
    [SellableEoh]         FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_EsdSupplyByDpWeek_CreatedOn] DEFAULT (getdate()) NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_EsdSupplyByDpWeek_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdDataSupplyStitchByStfMonth] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SnOPDemandProductId] ASC, [YearWw] ASC)
);

