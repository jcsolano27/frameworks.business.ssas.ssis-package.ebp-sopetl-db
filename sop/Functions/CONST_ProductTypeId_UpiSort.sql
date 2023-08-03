CREATE FUNCTION [sop].[CONST_ProductTypeId_UpiSort]
()
RETURNS INT
AS
BEGIN
    DECLARE @ProductTypeId INT = 0;
    SELECT @ProductTypeId = ProductTypeId
    FROM sop.ProductType
    WHERE ProductTypeNm = 'UPI_SORT';
    RETURN @ProductTypeId;
END;
