
CREATE FUNCTION [dbo].[CONST_DataQualityId_ParameterValidation]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_DataQualityId_ParameterValidation]()
	---- END TEST HARNESS

	DECLARE @DataQualityId INT = 0

	SELECT @DataQualityId = Id FROM dq.Configuration (NOLOCK) 
	WHERE DataQualityNm = 'Parameter Validation'
	
	RETURN @DataQualityId
END


