
CREATE FUNCTION dbo.CONST_ParameterId_TotalSupply()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_TotalSupply()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'TotalSupply'
	
	RETURN @ParameterId
END
