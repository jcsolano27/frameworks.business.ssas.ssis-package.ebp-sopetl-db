

CREATE FUNCTION [dbo].[CONST_ParameterId_FinancePorActuals]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_ParameterId_FinancePORForecast]()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.[Parameters] (NOLOCK) 
	WHERE ParameterName = 'Finance POR Actuals'
	
	RETURN @ParameterId
END
