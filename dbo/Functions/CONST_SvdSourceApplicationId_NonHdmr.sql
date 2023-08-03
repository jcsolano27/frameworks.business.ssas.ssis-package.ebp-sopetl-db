

CREATE FUNCTION [dbo].[CONST_SvdSourceApplicationId_NonHdmr]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_SvdSourceApplicationId_Hdmr]()
	---- END TEST HARNESS

	DECLARE @SvdSourceApplicationId INT = 0

	SELECT @SvdSourceApplicationId = SvdSourceApplicationId FROM [dbo].[SvdSourceApplications] (NOLOCK) 
	WHERE SvdSourceApplicationName = 'Non-Hdmr'
	
	RETURN @SvdSourceApplicationId
END
