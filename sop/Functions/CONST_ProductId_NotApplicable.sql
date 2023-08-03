
CREATE FUNCTION [sop].[CONST_ProductId_NotApplicable]()
RETURNS INT
AS
BEGIN

    DECLARE @ProductId INT = 0;
    SELECT @ProductId = ProductId
    FROM sop.Product
    WHERE ProductNm = 'N/A';
    RETURN @ProductId;
END;
