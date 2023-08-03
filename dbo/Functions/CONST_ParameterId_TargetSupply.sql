
CREATE FUNCTION [dbo].[CONST_ParameterId_TargetSupply]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_TargetSupply()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Strategy Target Supply'
	
	RETURN @ParameterId
END
