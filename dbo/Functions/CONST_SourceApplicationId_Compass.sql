
CREATE   FUNCTION [dbo].[CONST_SourceApplicationId_Compass]()
RETURNS INT
AS
BEGIN

	DECLARE @SourceApplicationId INT = 0

	SELECT @SourceApplicationId = SourceApplicationId FROM [dbo].[EtlSourceApplications] (NOLOCK) 
	WHERE SourceApplicationName = 'Compass'
	
	RETURN @SourceApplicationId
END

