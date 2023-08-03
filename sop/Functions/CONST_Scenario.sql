CREATE FUNCTION [sop].[CONST_Scenario]
(
@ScenarioNm VARCHAR(50)
)
RETURNS INT
AS
BEGIN

    DECLARE @ScenarioId INT = 0;

    SELECT @ScenarioId = ScenarioId
	FROM sop.Scenario
	WHERE ScenarioNm = @ScenarioNm

    RETURN @ScenarioId;
END;
