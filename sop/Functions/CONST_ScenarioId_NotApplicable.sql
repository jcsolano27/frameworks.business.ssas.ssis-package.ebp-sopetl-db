CREATE FUNCTION [sop].[CONST_ScenarioId_NotApplicable]
()
RETURNS INT
AS
BEGIN
    DECLARE @ScenarioId INT = 0;
    SELECT @ScenarioId = ScenarioId
    FROM sop.Scenario
    WHERE ScenarioNm = 'N/A';
    RETURN @ScenarioId;
END;
