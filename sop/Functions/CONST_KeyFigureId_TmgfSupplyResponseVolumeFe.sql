CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfSupplyResponseVolumeFe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Supply Response Volume/FE';
    RETURN @KeyFigureId;
END;
