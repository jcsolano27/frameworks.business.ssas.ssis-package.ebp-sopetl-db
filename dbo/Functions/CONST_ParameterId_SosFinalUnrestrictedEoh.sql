CREATE FUNCTION dbo.CONST_ParameterId_SosFinalUnrestrictedEoh()
RETURNS INT
AS
BEGIN
/*TEST HARNESS
	SELECT dbo.CONST_ParameterId_SosFinalUnrestrictedEoh()
*/

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'SoS Final Unrestricted EOH'
	
	RETURN @ParameterId
END
