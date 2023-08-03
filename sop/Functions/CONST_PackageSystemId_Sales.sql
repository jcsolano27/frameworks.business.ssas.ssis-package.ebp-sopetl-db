CREATE   FUNCTION [sop].[CONST_PackageSystemId_Sales]
()
RETURNS INT
AS
BEGIN
    DECLARE @PackageSystemId INT;

    SELECT @PackageSystemId = PackageSystemId
    FROM [sop].[PackageSystem]
    WHERE PackageSystemNm = 'SALES';

    RETURN @PackageSystemId;
END;
