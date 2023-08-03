
CREATE FUNCTION [dbo].[CONST_ParameterId_FinancePorForecast]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_ParameterId_FinancePORForecast]()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Finance POR Forecast'
	
	RETURN @ParameterId
END
