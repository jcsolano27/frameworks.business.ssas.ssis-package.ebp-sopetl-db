
CREATE FUNCTION [dbo].[CONST_ParameterId_SosUnrestrictedBoh]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_SosUnrestrictedBoh()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'SoS Unrestricted BOH'
	
	RETURN @ParameterId
END
