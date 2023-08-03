
CREATE FUNCTION [dbo].[CONST_ParameterId_FinancePorForecastBear]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_ParameterId_FinancePorForecastBear]()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Finance POR Forecast Bear'
	
	RETURN @ParameterId
END
