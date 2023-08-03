
CREATE FUNCTION [dbo].[CONST_DataQualityId_ProfitCenterCdc]()
RETURNS INT
AS
BEGIN

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = Id FROM dq.Configuration (NOLOCK) 
	WHERE DataQualityNm = 'Profit Center Change Control'
	
	RETURN @ParameterId
END


