CREATE FUNCTION [sop].[CONST_PlanVersionId_Bear]
()
RETURNS INT
AS
BEGIN
    DECLARE @PlanVersionId INT = 0;
    SELECT @PlanVersionId = PlanVersionId
    FROM sop.PlanVersion
    WHERE PlanVersionNm = 'Bear';
    RETURN @PlanVersionId;
END;
