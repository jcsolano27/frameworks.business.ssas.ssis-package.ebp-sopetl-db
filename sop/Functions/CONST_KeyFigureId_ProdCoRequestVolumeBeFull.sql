CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoRequestVolumeBeFull]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Request Volume/BE/Full';
    RETURN @KeyFigureId;
END;
