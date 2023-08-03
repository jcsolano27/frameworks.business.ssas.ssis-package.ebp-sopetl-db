CREATE FUNCTION [sop].[CONST_PlanVersionId_Base]
()
RETURNS INT
AS
BEGIN
    DECLARE @PlanVersionId INT = 0;
    SELECT @PlanVersionId = PlanVersionId
    FROM sop.PlanVersion
    WHERE PlanVersionNm = 'Base';
    RETURN @PlanVersionId;
END;
