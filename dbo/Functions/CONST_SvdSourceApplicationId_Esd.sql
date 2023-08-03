

CREATE FUNCTION [dbo].[CONST_SvdSourceApplicationId_Esd]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_SvdSourceApplicationId_Esd]()
	---- END TEST HARNESS

	DECLARE @SvdSourceApplicationId INT = 0

	SELECT @SvdSourceApplicationId = SvdSourceApplicationId FROM [dbo].[SvdSourceApplications] (NOLOCK) 
	WHERE SvdSourceApplicationName = 'ESD'
	
	RETURN @SvdSourceApplicationId
END
