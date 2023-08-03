CREATE FUNCTION [sop].[CONST_KeyFigureId_PrqCommit]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'PRQ Commit';
    RETURN @KeyFigureId;
END;
