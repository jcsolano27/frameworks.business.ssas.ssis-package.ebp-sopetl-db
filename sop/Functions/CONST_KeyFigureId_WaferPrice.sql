CREATE FUNCTION [sop].[CONST_KeyFigureId_WaferPrice]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Wafer Price';
    RETURN @KeyFigureId;
END;
