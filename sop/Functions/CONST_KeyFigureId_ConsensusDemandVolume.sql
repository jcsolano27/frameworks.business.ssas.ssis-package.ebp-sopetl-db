CREATE FUNCTION [sop].[CONST_KeyFigureId_ConsensusDemandVolume]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Consensus Demand Volume';
    RETURN @KeyFigureId;
END;
