CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfDemandDollarsFe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Demand Dollars/FE';
    RETURN @KeyFigureId;
END;
