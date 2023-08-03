CREATE FUNCTION dbo.CONST_SourceApplicationId_ESD()
RETURNS INT
AS
BEGIN
/*  START TEST HARNESS
	SELECT dbo.CONST_SourceApplicationId_ESD()
END TEST HARNESS */

	DECLARE @SourceApplicationId INT = 0

	SELECT @SourceApplicationId = SourceApplicationId FROM dbo.EtlSourceApplications
	WHERE SourceApplicationName = 'ESD'
	
	RETURN @SourceApplicationId
END
