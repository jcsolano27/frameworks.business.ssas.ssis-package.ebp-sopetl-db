CREATE FUNCTION [sop].[CONST_ProductTypeId_SnopDemandProduct]
()
RETURNS INT
AS
BEGIN
    DECLARE @ProductTypeId INT = 0;
    SELECT @ProductTypeId = ProductTypeId
    FROM sop.ProductType
    WHERE ProductTypeNm = 'SnOP Demand Product';
    RETURN @ProductTypeId;
END;
