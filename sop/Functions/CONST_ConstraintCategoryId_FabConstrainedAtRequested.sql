
CREATE FUNCTION [sop].[CONST_ConstraintCategoryId_FabConstrainedAtRequested]()
RETURNS INT
AS
BEGIN

    DECLARE @ConstraintCategoryId INT = 0;

    SELECT @ConstraintCategoryId = ConstraintCategoryId
    FROM [sop].[ConstraintCategory]
    WHERE ConstraintCategoryNm = 'Fab Constrained AT Requested';

    RETURN @ConstraintCategoryId;
END;
