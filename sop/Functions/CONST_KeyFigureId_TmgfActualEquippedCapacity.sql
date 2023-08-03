CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfActualEquippedCapacity]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Actual Equipped Capacity';
    RETURN @KeyFigureId;
END;
