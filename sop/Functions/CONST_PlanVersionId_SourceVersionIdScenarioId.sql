CREATE   FUNCTION [sop].[CONST_PlanVersionId_SourceVersionIdScenarioId]
(
    @SourceVersionId INT,
    @ScenarioId INT
)
RETURNS INT
AS
BEGIN

    DECLARE @PlanVersionId INT;

    SELECT @PlanVersionId = PlanVersionId
    FROM sop.PlanVersion
    WHERE SourceVersionId = @SourceVersionId
          AND ScenarioId = @ScenarioId;

    RETURN @PlanVersionId;
END;