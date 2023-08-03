
CREATE FUNCTION [sop].[CONST_ConstraintCategoryId_FabAndAtConstrained]()
RETURNS INT
AS
BEGIN

    DECLARE @ConstraintCategoryId INT = 0;

    SELECT @ConstraintCategoryId = ConstraintCategoryId
    FROM [sop].[ConstraintCategory]
    WHERE ConstraintCategoryNm = 'Fab and AT Constrained';

    RETURN @ConstraintCategoryId;
END;
