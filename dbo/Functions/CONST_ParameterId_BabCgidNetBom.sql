

CREATE FUNCTION [dbo].[CONST_ParameterId_BabCgidNetBom]()
RETURNS INT
AS
BEGIN
	DECLARE @ParameterId INT = 0

	SELECT @ParameterId = ParameterId FROM dbo.[Parameters] (NOLOCK) 
	WHERE ParameterName = 'BAB CGID Net BOM'
	
	RETURN @ParameterId
END