

CREATE FUNCTION [dbo].[CONST_PlanVersionId_NotApplicable]()
RETURNS INT
AS
BEGIN

/* TEST HARNESS --------------------------------------------------
------------------------------------------------------------------

SELECT [dbo].[CONST_PlanVersionId_NotApplicable]()

------------------------------------------------------------------
*/
	DECLARE @PlanVersionId INT = 0

	SELECT @PlanVersionId = PlanVersionId FROM sop.PlanVersion WITH(NOLOCK) 
	WHERE PlanVersionNm = 'N/A'
	
	RETURN @PlanVersionId
END
