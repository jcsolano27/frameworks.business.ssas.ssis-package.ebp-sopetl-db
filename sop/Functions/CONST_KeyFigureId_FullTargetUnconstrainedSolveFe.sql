CREATE FUNCTION [sop].[CONST_KeyFigureId_FullTargetUnconstrainedSolveFe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Full Target Unconstrained Solve/FE';
    RETURN @KeyFigureId;
END;