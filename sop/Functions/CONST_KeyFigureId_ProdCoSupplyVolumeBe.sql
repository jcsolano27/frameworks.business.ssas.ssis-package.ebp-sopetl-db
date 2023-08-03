CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoSupplyVolumeBe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Supply Volume/BE';
    RETURN @KeyFigureId;
END;
