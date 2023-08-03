CREATE   FUNCTION [sop].[CONST_PackageSystemId_Demand]
()
RETURNS INT
AS
BEGIN
    DECLARE @PackageSystemId INT;

    SELECT @PackageSystemId = PackageSystemId
    FROM [sop].[PackageSystem]
    WHERE PackageSystemNm = 'DEMAND';

    RETURN @PackageSystemId;
END;
