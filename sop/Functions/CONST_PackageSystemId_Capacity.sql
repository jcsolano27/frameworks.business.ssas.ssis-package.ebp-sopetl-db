CREATE   FUNCTION [sop].[CONST_PackageSystemId_Capacity]
()
RETURNS INT
AS
BEGIN
    DECLARE @PackageSystemId INT;

    SELECT @PackageSystemId = PackageSystemId
    FROM [sop].[PackageSystem]
    WHERE PackageSystemNm = 'CAPACITY';

    RETURN @PackageSystemId;
END;
