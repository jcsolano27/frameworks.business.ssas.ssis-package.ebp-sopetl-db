CREATE FUNCTION dbo.CONST_ParameterId_StrategyTargetEoh()
RETURNS INT
AS
BEGIN
/*TEST HARNESS
	SELECT dbo.CONST_ParameterId_StrategyTargetEoh()
*/

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Strategy Target EOH'
	
	RETURN @ParameterId
END
