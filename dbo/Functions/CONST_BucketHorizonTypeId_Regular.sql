
CREATE   FUNCTION [dbo].[CONST_BucketHorizonTypeId_Regular]()
    RETURNS VARCHAR(50)
AS
BEGIN
    RETURN (SELECT '1' AS BucketHorizonTypeId)
END
