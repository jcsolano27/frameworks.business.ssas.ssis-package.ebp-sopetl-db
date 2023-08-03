CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfSupplyResponseDollarsFe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Supply Response Dollars/FE';
    RETURN @KeyFigureId;
END;
