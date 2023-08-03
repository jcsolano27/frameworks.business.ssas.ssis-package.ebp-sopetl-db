CREATE FUNCTION [sop].[CONST_KeyFigureId_WaferCost]()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Wafer Cost';
    RETURN @KeyFigureId;
END;