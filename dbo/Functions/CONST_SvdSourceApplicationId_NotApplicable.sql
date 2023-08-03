



CREATE FUNCTION [dbo].[CONST_SvdSourceApplicationId_NotApplicable]()
RETURNS INT
AS
BEGIN


	DECLARE @SvdSourceApplicationId INT = 0

	SELECT @SvdSourceApplicationId = SvdSourceApplicationId FROM [dbo].[SvdSourceApplications] (NOLOCK) 
	WHERE SvdSourceApplicationName = 'N/A'
	
	RETURN @SvdSourceApplicationId
END
