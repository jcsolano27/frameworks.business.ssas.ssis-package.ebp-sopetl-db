CREATE FUNCTION [sop].[CONST_PlanVersionId_Bull]
()
RETURNS INT
AS
BEGIN
    DECLARE @PlanVersionId INT = 0;
    SELECT @PlanVersionId = PlanVersionId
    FROM sop.PlanVersion
    WHERE PlanVersionNm = 'Bull';
    RETURN @PlanVersionId;
END;