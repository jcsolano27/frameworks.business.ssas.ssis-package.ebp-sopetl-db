CREATE TABLE [dbo].[StgForecastMarketSegment] (
    [MarketSegmentId]         NVARCHAR (20)  NULL,
    [MarketSegmentNm]         NVARCHAR (50)  NULL,
    [AllMarketSegmentId]      NVARCHAR (3)   NULL,
    [AllMarketSegmentNm]      NVARCHAR (15)  NULL,
    [MarketSegmentGroupNm]    NVARCHAR (40)  NULL,
    [ForecastMarketSegmentNm] NVARCHAR (100) NULL,
    [ActiveInd]               NVARCHAR (250) NULL,
    [CreateDtm]               DATETIME       NULL,
    [CreateUserNm]            NVARCHAR (250) NULL,
    [LastUpdateUserDtm]       DATETIME       NULL,
    [LastUpdateUserNm]        NVARCHAR (20)  NULL,
    [LastUpdateSystemUserDtm] DATETIME       NULL,
    [LastUpdateSystemUserNm]  NVARCHAR (250) NULL,
    [CreatedOn]               DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedBy]               NVARCHAR (25)  DEFAULT (original_login()) NOT NULL
);

