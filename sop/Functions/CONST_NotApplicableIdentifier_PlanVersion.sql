CREATE FUNCTION [sop].[CONST_NotApplicableIdentifier_PlanVersion]
()
RETURNS INT
AS
BEGIN
    DECLARE @NotAplicableIdentifier INT = 0;

    SELECT @NotAplicableIdentifier = PlanVersionId
    FROM sop.PlanVersion
    WHERE PlanVersionNm = 'N/A';

    RETURN @NotAplicableIdentifier;
END;