CREATE TABLE [dbo].[SvdItemRevenueSegmentPc] (
    [RevenueSegmentNm] NVARCHAR (100) NOT NULL,
    [ProfitCenterCd]   NVARCHAR (100) NOT NULL,
    [LastModifiedDt]   DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedOn]        DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedBy]        VARCHAR (25)   DEFAULT (original_login()) NOT NULL,
    [IsActive]         BIT            NULL,
    PRIMARY KEY CLUSTERED ([RevenueSegmentNm] ASC, [ProfitCenterCd] ASC)
);

