CREATE FUNCTION [sop].[CONST_NotApplicableIdentifier_Product]
()
RETURNS INT
AS
BEGIN
    DECLARE @NotAplicableIdentifier INT = 0;

    SELECT @NotAplicableIdentifier = ProductId
    FROM sop.Product
    WHERE ProductNm = 'N/A';

    RETURN @NotAplicableIdentifier;
END;