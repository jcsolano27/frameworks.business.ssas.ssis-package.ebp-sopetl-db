
CREATE FUNCTION [sop].[CONST_ConstraintCategoryId_Unconstrained]()
RETURNS INT
AS
BEGIN

    DECLARE @ConstraintCategoryId INT = 0;

    SELECT @ConstraintCategoryId = ConstraintCategoryId
    FROM [sop].[ConstraintCategory]
    WHERE ConstraintCategoryNm = 'Unconstrained';

    RETURN @ConstraintCategoryId;
END;
