



CREATE FUNCTION [dbo].[CONST_BusinessGroupingId_NotApplicable]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_BusinessGroupingId_NotApplicable]()
	---- END TEST HARNESS

	DECLARE @BusinessGroupingId INT = 0

	SELECT @BusinessGroupingId = BusinessGroupingId FROM [dbo].[BusinessGrouping] (NOLOCK) 
	WHERE  SnOPComputeArchitectureNm = 'N/A' AND SnOPProcessNodeNm = 'N/A'
	
	RETURN @BusinessGroupingId
END
