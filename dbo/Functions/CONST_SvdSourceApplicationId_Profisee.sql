

CREATE FUNCTION [dbo].[CONST_SvdSourceApplicationId_Profisee]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_SvdSourceApplicationId_Profisee]()
	---- END TEST HARNESS

	DECLARE @SvdSourceApplicationId INT = 0

	SELECT @SvdSourceApplicationId = SvdSourceApplicationId FROM [dbo].[SvdSourceApplications] (NOLOCK) 
	WHERE SvdSourceApplicationName = 'Profisee'
	
	RETURN @SvdSourceApplicationId
END
