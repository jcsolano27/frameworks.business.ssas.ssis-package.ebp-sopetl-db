CREATE FUNCTION sop.CONST_NotApplicableIdentifier_SourceSystem
()
RETURNS INT
AS
BEGIN
    DECLARE @NotAplicableIdentifier INT = 0;

    SELECT @NotAplicableIdentifier = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'N/A';

    RETURN @NotAplicableIdentifier;
END;