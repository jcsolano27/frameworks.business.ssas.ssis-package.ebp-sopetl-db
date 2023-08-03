CREATE FUNCTION [sop].[CONST_CustomerId_NotApplicable]
()
RETURNS INT
AS
BEGIN
    DECLARE @CustomerId INT = 0;
    SELECT @CustomerId = CustomerId
    FROM sop.Customer
    WHERE CustomerNm = 'N/A';
    RETURN @CustomerId;
END;
