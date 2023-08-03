

CREATE   FUNCTION [dbo].[CONST_SourceApplicationId_OneMps]()
RETURNS INT
AS
BEGIN
	DECLARE @SourceApplicationId INT = 0

	SELECT @SourceApplicationId = SourceApplicationId FROM [dbo].[EtlSourceApplications] (NOLOCK) 
	WHERE SourceApplicationName = 'OneMps'
	
	RETURN @SourceApplicationId
END
