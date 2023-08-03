CREATE   FUNCTION [sop].[CONST_PackageSystemId_Dimension]
()
RETURNS INT
AS
BEGIN
    DECLARE @PackageSystemId INT;

    SELECT @PackageSystemId = PackageSystemId
    FROM [sop].[PackageSystem]
    WHERE PackageSystemNm = 'DIMENSION';

    RETURN @PackageSystemId;
END;