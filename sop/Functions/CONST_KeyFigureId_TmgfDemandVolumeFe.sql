CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfDemandVolumeFe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Demand Volume/FE';
    RETURN @KeyFigureId;
END;
