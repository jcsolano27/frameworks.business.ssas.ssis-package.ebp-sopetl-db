CREATE FUNCTION sop.fnGetPlanVersionId_OneMpsSourceVersioId
(
    @SourceVersionId INT
)
RETURNS INT
AS
BEGIN

    DECLARE @PlanVersionId INT;

    SELECT @PlanVersionId = P.PlanVersionId
    FROM sop.PlanVersion P
        JOIN dbo.EsdVersions E
            ON P.ConstraintCategoryId = sop.CONST_ConstraintCategoryId_Unconstrained()
               AND P.SourceVersionId = E.EsdVersionId
        JOIN dbo.EsdSourceVersions S
            ON S.EsdVersionId = E.EsdVersionId
    WHERE S.SourceVersionId = @SourceVersionId
          AND S.SourceApplicationId = [dbo].[CONST_SourceApplicationId_OneMps]();

    RETURN @PlanVersionId;
END;