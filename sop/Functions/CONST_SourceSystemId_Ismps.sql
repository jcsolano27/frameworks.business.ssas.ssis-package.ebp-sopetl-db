CREATE   FUNCTION [sop].[CONST_SourceSystemId_Ismps]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'Ismps';

    RETURN @SourceSystemId;
END;
