CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestDollarsBeCbf]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Dollars/BE/CBF';
    RETURN @KeyFigureId;
END;
