CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeFull]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Volume/FE/Full';
    RETURN @KeyFigureId;
END;
