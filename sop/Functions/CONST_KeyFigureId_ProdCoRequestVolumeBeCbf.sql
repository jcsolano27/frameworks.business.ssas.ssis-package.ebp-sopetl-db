CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeCbf]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Volume/BE/CBF';
    RETURN @KeyFigureId;
END;
