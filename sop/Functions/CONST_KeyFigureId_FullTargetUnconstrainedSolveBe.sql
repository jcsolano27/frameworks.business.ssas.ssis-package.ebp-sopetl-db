CREATE FUNCTION [sop].[CONST_KeyFigureId_FullTargetUnconstrainedSolveBe]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Full Target Unconstrained Solve/BE';
    RETURN @KeyFigureId;
END;