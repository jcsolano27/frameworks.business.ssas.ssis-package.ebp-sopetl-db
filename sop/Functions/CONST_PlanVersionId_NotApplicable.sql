CREATE FUNCTION [sop].[CONST_PlanVersionId_NotApplicable]
()
RETURNS INT
AS
BEGIN

    DECLARE @PlanVersionId INT = 0;
    SELECT @PlanVersionId = PlanVersionId
    FROM sop.PlanVersion
    WHERE PlanVersionNm = 'N/A';
    RETURN @PlanVersionId;
END;
