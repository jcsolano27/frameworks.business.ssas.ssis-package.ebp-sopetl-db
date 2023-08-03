CREATE FUNCTION [sop].[CONST_KeyFigureId_ConsensusDemandDollars]
()
RETURNS INT
AS
BEGIN

    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Consensus Demand Dollars';
    RETURN @KeyFigureId;
END;
