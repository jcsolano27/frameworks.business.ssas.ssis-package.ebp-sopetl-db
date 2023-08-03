CREATE TABLE [dbo].[IntelCalendar] (
    [WwId]         INT          IDENTITY (1, 1) NOT NULL,
    [MonthId]      INT          NOT NULL,
    [YearWw]       INT          NOT NULL,
    [YearMonth]    INT          NOT NULL,
    [YearQq]       INT          NOT NULL,
    [IntelMonth]   INT          NOT NULL,
    [IntelQuarter] INT          NOT NULL,
    [IntelYear]    INT          NOT NULL,
    [StartDate]    DATETIME     NOT NULL,
    [EndDate]      DATETIME     NOT NULL,
    [CreatedOn]    DATETIME     NULL,
    [CreatedBy]    VARCHAR (25) NULL,
    CONSTRAINT [PkIntelCalendarWwId] PRIMARY KEY CLUSTERED ([WwId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IdxIntelCalendarYearQq]
    ON [dbo].[IntelCalendar]([YearQq] ASC);


GO
CREATE NONCLUSTERED INDEX [IdxIntelCalendarYearMonth]
    ON [dbo].[IntelCalendar]([YearMonth] ASC);

