CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfDemandVolumeBe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Demand Volume/BE';
    RETURN @KeyFigureId;
END;
