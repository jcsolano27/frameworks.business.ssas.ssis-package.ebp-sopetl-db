
CREATE FUNCTION [dbo].[CONST_ParameterId_Billings]()
RETURNS INT
AS
BEGIN

	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.Parameters (NOLOCK) 
	WHERE ParameterName = 'Billings'
	
	RETURN @ParameterId
END
