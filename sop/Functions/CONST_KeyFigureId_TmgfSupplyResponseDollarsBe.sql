CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfSupplyResponseDollarsBe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Supply Response Dollars/BE';
    RETURN @KeyFigureId;
END;
