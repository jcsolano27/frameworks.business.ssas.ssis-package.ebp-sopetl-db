
CREATE FUNCTION [sop].[CONST_ConstraintCategoryId_NotApplicable]()
RETURNS INT
AS
BEGIN

    DECLARE @ConstraintCategoryId INT = 0;

    SELECT @ConstraintCategoryId = ConstraintCategoryId
    FROM [sop].[ConstraintCategory]
    WHERE ConstraintCategoryNm = 'N/A';

    RETURN @ConstraintCategoryId;
END;
