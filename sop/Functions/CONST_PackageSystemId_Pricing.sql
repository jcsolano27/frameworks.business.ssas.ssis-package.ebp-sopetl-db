CREATE   FUNCTION [sop].[CONST_PackageSystemId_Pricing]
()
RETURNS INT
AS
BEGIN
    DECLARE @PackageSystemId INT;

    SELECT @PackageSystemId = PackageSystemId
    FROM [sop].[PackageSystem]
    WHERE PackageSystemNm = 'PRICING';

    RETURN @PackageSystemId;
END;
