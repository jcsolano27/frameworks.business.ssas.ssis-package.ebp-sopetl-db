CREATE FUNCTION [sop].[CONST_KeyFigureId_TmgfActualCommitCapacity]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'TMGF Actual Commit Capacity';
    RETURN @KeyFigureId;
END;
