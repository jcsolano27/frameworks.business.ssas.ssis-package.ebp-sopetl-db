CREATE FUNCTION [sop].[CONST_ProductTypeId_SnopSupplyProduct]
()
RETURNS INT
AS
BEGIN
    DECLARE @ProductTypeId INT = 0;
    SELECT @ProductTypeId = ProductTypeId
    FROM sop.ProductType
    WHERE ProductTypeNm = 'SnOP Supply Product';
    RETURN @ProductTypeId;
END;
