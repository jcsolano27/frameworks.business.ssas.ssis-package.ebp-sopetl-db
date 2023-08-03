CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestDollarsBeFull]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Dollars/BE/Full';
    RETURN @KeyFigureId;
END;
