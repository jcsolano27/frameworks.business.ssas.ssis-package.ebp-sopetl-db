CREATE FUNCTION [sop].[CONST_NotApplicableIdentifier_Scenario]
()
RETURNS INT
AS
BEGIN
    DECLARE @NotAplicableIdentifier INT = 0;

    SELECT @NotAplicableIdentifier = ScenarioId
    FROM sop.Scenario
    WHERE ScenarioNm = 'N/A';

    RETURN @NotAplicableIdentifier;
END;