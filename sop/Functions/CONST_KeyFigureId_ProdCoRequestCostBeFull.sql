CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestCostBeFull]()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Cost/BE/Full';
    RETURN @KeyFigureId;
END;