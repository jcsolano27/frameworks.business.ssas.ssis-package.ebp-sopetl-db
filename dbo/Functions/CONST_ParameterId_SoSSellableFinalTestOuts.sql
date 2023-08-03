
CREATE FUNCTION [dbo].[CONST_ParameterId_SoSSellableFinalTestOuts]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_SellableSupply()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'SoS Sellable Final Test Outs'
	
	RETURN @ParameterId
END
