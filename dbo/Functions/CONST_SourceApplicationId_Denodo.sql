



CREATE FUNCTION [dbo].[CONST_SourceApplicationId_Denodo]()
RETURNS INT
AS
BEGIN


	DECLARE @SourceApplicationId INT = 0

	SELECT @SourceApplicationId = SourceApplicationId FROM [dbo].[EtlSourceApplications] (NOLOCK) 
	WHERE SourceApplicationName = 'Denodo'
	
	RETURN @SourceApplicationId
END
