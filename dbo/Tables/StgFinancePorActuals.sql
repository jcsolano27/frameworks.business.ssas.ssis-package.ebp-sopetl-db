CREATE TABLE [dbo].[StgFinancePorActuals] (
    [ItemId]              NVARCHAR (50) NOT NULL,
    [YearQq]              NVARCHAR (50) NOT NULL,
    [RevenueSuperGroupCd] NVARCHAR (50) NOT NULL,
    [RevenueSegmentNm]    NVARCHAR (50) NOT NULL,
    [RevenueNetQty]       FLOAT (53)    NOT NULL,
    [CreatedOn]           DATETIME      DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25)  DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([ItemId] ASC, [YearQq] ASC, [RevenueSuperGroupCd] ASC, [RevenueSegmentNm] ASC, [RevenueNetQty] ASC)
);

