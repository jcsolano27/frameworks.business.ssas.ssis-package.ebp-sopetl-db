

CREATE FUNCTION [dbo].[CONST_ParameterId_RegionalDemandAnalysisDraft]()
RETURNS INT
AS
BEGIN
	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.[Parameters] (NOLOCK) 
	WHERE ParameterName = 'Regional Demand Analysis Draft'
	
	RETURN @ParameterId
END
