CREATE FUNCTION [sop].[CONST_PackageSystemId_PackageSystemNm]
(
    @PackageSystemNm VARCHAR(25)
)
RETURNS INT
AS
BEGIN
    DECLARE @PackageSystemId INT;

    SELECT @PackageSystemId = PackageSystemId
    FROM [sop].[PackageSystem]
    WHERE PackageSystemNm = @PackageSystemNm;

    RETURN @PackageSystemId;
END;