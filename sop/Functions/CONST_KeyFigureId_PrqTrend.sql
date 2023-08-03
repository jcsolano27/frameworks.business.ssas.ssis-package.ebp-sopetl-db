CREATE FUNCTION [sop].[CONST_KeyFigureId_PrqTrend]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'PRQ Trend';
    RETURN @KeyFigureId;
END;
