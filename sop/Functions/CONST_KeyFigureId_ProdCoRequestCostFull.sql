CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestCostFull]()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Cost/Full';
    RETURN @KeyFigureId;
END;
