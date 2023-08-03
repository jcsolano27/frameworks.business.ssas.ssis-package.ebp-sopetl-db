CREATE FUNCTION dbo.CONST_ParameterId_StrategyTargetSupply()
RETURNS INT
AS
BEGIN
/*TEST HARNESS
	SELECT dbo.CONST_ParameterId_StrategyTargetSupply()
*/

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Strategy Target Supply'
	
	RETURN @ParameterId
END
