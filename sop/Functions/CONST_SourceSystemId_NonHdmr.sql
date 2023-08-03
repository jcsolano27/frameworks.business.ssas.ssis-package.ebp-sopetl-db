CREATE   FUNCTION [sop].[CONST_SourceSystemId_NonHdmr]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'Non-Hdmr';

    RETURN @SourceSystemId;
END;
