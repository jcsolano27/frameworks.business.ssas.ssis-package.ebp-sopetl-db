CREATE PROC [dbo].[UspEbpGrantExecute] AS 

DECLARE @SqlCode1 NVARCHAR(MAX), @SqlCode2  NVARCHAR(MAX), @SqlCode3  NVARCHAR(MAX);
SET @SqlCode1 =(SELECT CONCAT('GRANT EXECUTE ON ', NAME, ' TO [amr\ebp sdra datamart bb developer]; ') FROM sys.objects WHERE type = 'P' AND Name like 'uspReportSvdFetch%' FOR XML PATH(''));
SET @SqlCode2 = (SELECT CONCAT('GRANT EXECUTE ON ', NAME, ' TO [amr\ebp sdra datamart svd tool pre-prod];') FROM sys.objects WHERE type = 'P' AND Name like 'uspReportSvdFetch%' FOR XML PATH(''));
SET @SqlCode3 = (SELECT CONCAT('GRANT EXECUTE ON ', NAME, ' TO [amr\ebp sdra datamart gb developer];') FROM sys.objects WHERE type = 'P' AND Name like 'uspReportSvdFetch%' FOR XML PATH(''));

EXEC (@SqlCode1)
EXEC (@SqlCode2)
EXEC (@SqlCode3)
