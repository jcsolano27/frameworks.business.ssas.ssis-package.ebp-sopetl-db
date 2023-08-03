CREATE TABLE [dbo].[StgItemRevenueSegmentPC] (
    [RevenueSegmentNm]       NVARCHAR (100) NOT NULL,
    [ProfitCenterCd]         NVARCHAR (11)  NOT NULL,
    [EffectiveFromQuarterNm] NVARCHAR (6)   NOT NULL,
    [EffectiveToQuarterNm]   NVARCHAR (6)   NOT NULL,
    [CreatedOn]              DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25)   DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([RevenueSegmentNm] ASC, [ProfitCenterCd] ASC, [EffectiveFromQuarterNm] ASC, [EffectiveToQuarterNm] ASC)
);

