CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;

    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Revenue Dollars (RevOpt)';

    RETURN @KeyFigureId;
END;