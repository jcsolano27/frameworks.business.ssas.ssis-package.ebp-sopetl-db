CREATE FUNCTION [sop].[CONST_KeyFigureId_ProductionDieOutActuals]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Production Die Out Actuals';
    RETURN @KeyFigureId;
END;
