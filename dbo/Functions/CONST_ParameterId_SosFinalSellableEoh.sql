CREATE FUNCTION dbo.CONST_ParameterId_SosFinalSellableEoh()
RETURNS INT
AS
BEGIN
/*TEST HARNESS
	SELECT dbo.CONST_ParameterId_SosFinalSellableEoh()
*/

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'SoS Final Sellable EOH'
	
	RETURN @ParameterId
END
