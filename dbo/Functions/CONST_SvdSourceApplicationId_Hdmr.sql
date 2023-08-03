

create FUNCTION [dbo].[CONST_SvdSourceApplicationId_Hdmr]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_SvdSourceApplicationId_Hdmr]()
	---- END TEST HARNESS

	DECLARE @SvdSourceApplicationId INT = 0

	SELECT @SvdSourceApplicationId = SvdSourceApplicationId FROM [dbo].[SvdSourceApplications] (NOLOCK) 
	WHERE SvdSourceApplicationName = 'Hdmr'
	
	RETURN @SvdSourceApplicationId
END
