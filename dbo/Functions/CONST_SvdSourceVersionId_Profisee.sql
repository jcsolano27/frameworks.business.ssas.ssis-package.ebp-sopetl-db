

CREATE FUNCTION [dbo].[CONST_SvdSourceVersionId_Profisee]()
RETURNS INT
AS
BEGIN
	---- START TEST HARNESS
	--SELECT dbo.[CONST_SvdSourceVersionId_Profisee]()
	---- END TEST HARNESS

	DECLARE @SvdSourceVersionId INT = 0

	SELECT @SvdSourceVersionId = SvdSourceVersionId FROM [dbo].[SvdSourceVersion] (NOLOCK) 
	WHERE SourceVersionNm = 'Profisee Finance Por Base/Bull/Bear'
	
	RETURN @SvdSourceVersionId
END
