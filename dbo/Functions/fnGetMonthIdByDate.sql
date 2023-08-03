



CREATE FUNCTION [dbo].[fnGetMonthIdByDate]
(
	@DtBaseDate DATETIME
)
RETURNS INT
AS

/****************************************************************************************************************
DESCRIPTION: Returns YearMonth for a specified date
*****************************************************************************************************************/

/* ---- TEST HARNESS
DECLARE @YearMonth INT
SET @YearMonth = [dbo].[fnGetMonthIdByDate](GETDATE())
SELECT @YearMonth
--- END TEST HARNESS*/

BEGIN
	DECLARE @YyyyMm INT
    DECLARE @MonthId INT
	
	set @MonthId =
	(
		SELECT MIN(MonthId)
		FROM dbo.IntelCalendar (NOLOCK)
		WHERE CONVERT(SMALLDATETIME, @DtBaseDate) BETWEEN StartDate and EndDate
	)

	RETURN @MonthId
END

