
CREATE FUNCTION [dbo].[CONST_ProfitCenterCd_NotApplicable]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_ProfitCenterCd_NotApplicable]()
	---- END TEST HARNESS

	DECLARE @ProfitCenterCd INT = 0

	SELECT @ProfitCenterCd = ProfitCenterCd FROM [dbo].[ProfitCenterHierarchy] (NOLOCK) 
	WHERE  ProfitCenterNm = 'N/A'
	
	RETURN @ProfitCenterCd
END

