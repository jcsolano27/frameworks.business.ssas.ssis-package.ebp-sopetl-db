CREATE FUNCTION [sop].[CONST_NotApplicableIdentifier_ProfitCenter]
()
RETURNS INT
AS
BEGIN
    DECLARE @NotAplicableIdentifier INT = 0;

    SELECT @NotAplicableIdentifier = ProfitCenterCd
    FROM sop.ProfitCenter
    WHERE ProfitCenterNm = 'N/A';

    RETURN @NotAplicableIdentifier;
END;