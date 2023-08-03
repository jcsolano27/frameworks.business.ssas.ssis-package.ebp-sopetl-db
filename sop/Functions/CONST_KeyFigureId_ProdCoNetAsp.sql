CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoNetAsp]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Product Net ASP';
    RETURN @KeyFigureId;
END;
