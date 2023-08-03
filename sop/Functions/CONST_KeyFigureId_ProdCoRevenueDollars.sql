CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRevenueDollars]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;

    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Revenue Dollars';

    RETURN @KeyFigureId;
END;