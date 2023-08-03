
CREATE FUNCTION [dbo].[CONST_ParameterId_SosDemand]()
RETURNS INT
AS
BEGIN
/*TEST HARNESS
	SELECT dbo.CONST_ParameterId_SosDemand()
*/

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'SoS Demand Adjustments'
	
	RETURN @ParameterId
END
