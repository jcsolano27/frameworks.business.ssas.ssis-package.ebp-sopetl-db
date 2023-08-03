CREATE FUNCTION [sop].[CONST_KeyFigureId_FgCost]()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Fg Cost';
    RETURN @KeyFigureId;
END;