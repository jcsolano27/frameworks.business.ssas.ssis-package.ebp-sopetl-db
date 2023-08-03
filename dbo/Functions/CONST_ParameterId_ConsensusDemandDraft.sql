

CREATE FUNCTION [dbo].[CONST_ParameterId_ConsensusDemandDraft]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.CONST_ParameterId_ConsensusDemandDraft()
	---- END TEST HARNESS

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Consensus Demand Forecast Draft'
	
	RETURN @ParameterId
END
