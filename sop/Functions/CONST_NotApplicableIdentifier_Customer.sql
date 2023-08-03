CREATE FUNCTION [sop].[CONST_NotApplicableIdentifier_Customer]
()
RETURNS INT
AS
BEGIN
    DECLARE @NotAplicableIdentifier INT = 0;

    SELECT @NotAplicableIdentifier = CustomerId
    FROM sop.Customer
    WHERE CustomerNm = 'N/A';

    RETURN @NotAplicableIdentifier;
END;