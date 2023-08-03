CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoCost]()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Cost';
    RETURN @KeyFigureId;
END;
