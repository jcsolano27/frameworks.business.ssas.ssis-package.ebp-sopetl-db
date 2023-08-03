CREATE FUNCTION [sop].[CONST_KeyFigureId_PrqActual]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'PRQ Actual';
    RETURN @KeyFigureId;
END;

