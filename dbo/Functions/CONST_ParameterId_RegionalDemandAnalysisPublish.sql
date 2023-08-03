
CREATE FUNCTION [dbo].[CONST_ParameterId_RegionalDemandAnalysisPublish]()
RETURNS INT
AS
BEGIN
	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.[Parameters] (NOLOCK) 
	WHERE ParameterName = 'Regional Demand Analysis Publish'
	
	RETURN @ParameterId
END
