
CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestCostFeFull]()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Cost/FE/Full';
    RETURN @KeyFigureId;
END;