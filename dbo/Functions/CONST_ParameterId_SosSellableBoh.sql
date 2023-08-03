
CREATE FUNCTION [dbo].[CONST_ParameterId_SosSellableBoh]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_SosSellableBoh()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'SoS Sellable BOH'
	
	RETURN @ParameterId
END
