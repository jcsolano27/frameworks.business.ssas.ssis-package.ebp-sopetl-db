CREATE FUNCTION [sop].[CONST_KeyFigureId_IfsRequestVolumeFe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'IFS Request Volume/FE';
    RETURN @KeyFigureId;
END;
