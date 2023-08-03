CREATE TABLE [dbo].[SopFiscalCalendar] (
    [SourceApplicationName]            VARCHAR (25)   NOT NULL,
    [SourceVersionId]                  INT            NOT NULL,
    [FiscalCalendarIdentifier]         INT            NOT NULL,
    [StartDate]                        DATETIME       NULL,
    [LastMonthOfFiscalQuarterNbr]      NVARCHAR (4)   NULL,
    [FiscalQuarterNbr]                 NVARCHAR (2)   NULL,
    [FiscalQuarterWorkweekNbr]         NVARCHAR (5)   NULL,
    [RelativeFiscalMonthsFromTodayNbr] INT            NULL,
    [RelativeQuarter]                  INT            NULL,
    [RelativeWorkweek]                 INT            NULL,
    [RelativeYear]                     INT            NULL,
    [WorkWeekNm]                       NVARCHAR (8)   NULL,
    [WorkWeekNbr]                      NVARCHAR (6)   NULL,
    [FiscalAbbreviatedMonthYearNm]     NVARCHAR (40)  NULL,
    [FiscalMonthNm]                    NVARCHAR (10)  NULL,
    [FiscalMonthNbr]                   NVARCHAR (4)   NULL,
    [YearNbr]                          NVARCHAR (8)   NULL,
    [FiscalYearQuarterName]            NVARCHAR (12)  NULL,
    [FiscalYearQuarterNbr]             NVARCHAR (12)  NULL,
    [Workweek]                         NVARCHAR (12)  NULL,
    [WeeksInFiscalMonthCnt]            BIGINT         NULL,
    [WeeksInFiscalQuarterCnt]          BIGINT         NULL,
    [FiscalPeriodEndDateTxt]           NVARCHAR (20)  NULL,
    [RelativeDaysFromTodayNbr]         INT            NULL,
    [FiscalMonthWorkweekNbr]           NVARCHAR (10)  NULL,
    [FiscalQuarterMonthNbr]            NVARCHAR (2)   NULL,
    [CalendarCharDt]                   NVARCHAR (16)  NULL,
    [FiscalYearMonthNm]                NVARCHAR (20)  NULL,
    [FiscalYearMonthNbr]               NVARCHAR (12)  NULL,
    [SourceNm]                         NVARCHAR (30)  NULL,
    [LastYearMonthOfFiscalQuarterNbr]  NVARCHAR (255) NULL,
    [CreatedOn]                        DATETIME       CONSTRAINT [DF_SopFiscalCalendar_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                        VARCHAR (25)   CONSTRAINT [DF_SopFiscalCalendar_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]                       DATETIME       NULL,
    [UpdatedBy]                        VARCHAR (25)   NULL,
    CONSTRAINT [PK_SopFiscalCalendar] PRIMARY KEY CLUSTERED ([FiscalCalendarIdentifier] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IDX_SopFiscalCalendar_001]
    ON [dbo].[SopFiscalCalendar]([FiscalCalendarIdentifier] ASC, [SourceNm] ASC);


GO
CREATE NONCLUSTERED INDEX [IdxSopFiscalCalendarSourceNmMonthNbr]
    ON [dbo].[SopFiscalCalendar]([SourceNm] ASC)
    INCLUDE([FiscalYearMonthNbr]);


GO
CREATE NONCLUSTERED INDEX [IdxSopFiscalCalendarSourceNm]
    ON [dbo].[SopFiscalCalendar]([SourceNm] ASC)
    INCLUDE([FiscalYearQuarterNbr]);

