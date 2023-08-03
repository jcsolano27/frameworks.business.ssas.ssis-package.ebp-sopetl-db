CREATE   FUNCTION [sop].[CONST_SourceSystemId_Hdmr]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'Hdmr';

    RETURN @SourceSystemId;
END;