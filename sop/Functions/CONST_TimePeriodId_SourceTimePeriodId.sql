CREATE   FUNCTION [sop].[CONST_TimePeriodId_SourceTimePeriodId]
(
    @SourceTimePeriodId INT
)
RETURNS INT
AS
BEGIN
    DECLARE @TimePeriodId INT = 0;

    SELECT @TimePeriodId = TimePeriodId
    FROM [sop].[TimePeriod]
    WHERE SourceTimePeriodId = @SourceTimePeriodId;

    RETURN @TimePeriodId;
END;