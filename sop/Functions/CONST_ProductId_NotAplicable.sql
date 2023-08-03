CREATE FUNCTION sop.CONST_ProductId_NotAplicable
()
RETURNS INT
AS
BEGIN

    DECLARE @ProductId INT;

    SELECT @ProductId = ProductId
    FROM sop.Product
    WHERE ProductNm = 'N/A';

    RETURN @ProductId;
END;