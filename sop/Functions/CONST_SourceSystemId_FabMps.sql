CREATE   FUNCTION [sop].[CONST_SourceSystemId_FabMps]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'FabMps';

    RETURN @SourceSystemId;
END;