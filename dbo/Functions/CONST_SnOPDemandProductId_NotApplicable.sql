
CREATE FUNCTION [dbo].[CONST_SnOPDemandProductId_NotApplicable]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_SnOPDemandProductId_NotApplicable]()
	---- END TEST HARNESS

	DECLARE @SnOPDemandProductId INT = 0

	SELECT @SnOPDemandProductId = SnOPDemandProductId FROM [dbo].[SnOPDemandProductHierarchy] (NOLOCK) 
	WHERE SnOPDemandProductNm = 'Not Applicable'
	
	RETURN @SnOPDemandProductId
END