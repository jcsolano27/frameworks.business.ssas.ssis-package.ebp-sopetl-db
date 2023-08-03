
-- Scalar Functions 

CREATE FUNCTION [dbo].[CONST_DataQualityId_DemandProductHierarchyCDC]()
RETURNS INT
AS
BEGIN

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = Id FROM dq.Configuration (NOLOCK) 
	WHERE DataQualityNm = 'Demand Product Hierarchy Change Control'
	
	RETURN @ParameterId
END
