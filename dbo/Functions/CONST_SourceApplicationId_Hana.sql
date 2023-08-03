

CREATE FUNCTION [dbo].[CONST_SourceApplicationId_Hana]()
RETURNS INT
AS
BEGIN
	DECLARE @SourceApplicationId INT = 0

	SELECT @SourceApplicationId = SourceApplicationId FROM [dbo].[EtlSourceApplications] (NOLOCK) 
	WHERE SourceApplicationName = 'Hana'
	
	RETURN @SourceApplicationId
END
