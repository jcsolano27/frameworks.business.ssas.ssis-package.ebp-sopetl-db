
CREATE FUNCTION [sop].[CONST_PlanVersionId_Actuals]
()
RETURNS INT
AS
BEGIN
    DECLARE @PlanVersionId INT = 0;
    SELECT @PlanVersionId = PlanVersionId
    FROM sop.PlanVersion
    WHERE PlanVersionNm = 'Actuals';
    RETURN @PlanVersionId;
END;
