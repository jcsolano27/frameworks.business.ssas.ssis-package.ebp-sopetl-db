CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoSupplyDollarsBe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Supply Dollars/BE';
    RETURN @KeyFigureId;
END;
