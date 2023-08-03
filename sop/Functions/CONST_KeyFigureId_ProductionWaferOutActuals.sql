
CREATE FUNCTION [sop].[CONST_KeyFigureId_ProductionWaferOutActuals]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Production Wafer Out Actuals';
    RETURN @KeyFigureId;
END;
