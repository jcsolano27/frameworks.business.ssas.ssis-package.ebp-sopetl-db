

CREATE FUNCTION [dbo].[CONST_ParameterId_ConsensusDemandBear]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_ConsensusDemandBear()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Consensus Demand Forecast Bear'
	
	RETURN @ParameterId
END
