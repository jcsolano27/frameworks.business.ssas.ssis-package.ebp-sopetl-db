CREATE FUNCTION [sop].[CONST_ScenarioId_Base]
()
RETURNS INT
AS
BEGIN
    DECLARE @ScenarioId INT = 0;
    SELECT @ScenarioId = ScenarioId
    FROM sop.Scenario
    WHERE ScenarioNm = 'Base';
    RETURN @ScenarioId;
END;
