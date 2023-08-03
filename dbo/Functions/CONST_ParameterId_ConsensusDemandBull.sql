

CREATE FUNCTION [dbo].[CONST_ParameterId_ConsensusDemandBull]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_ConsensusDemandBull()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Consensus Demand Forecast Bull'
	
	RETURN @ParameterId
END
