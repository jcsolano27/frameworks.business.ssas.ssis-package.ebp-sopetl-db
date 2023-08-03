CREATE   FUNCTION [sop].[CONST_SourceSystemId_OneMps]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'OneMps';

    RETURN @SourceSystemId;
END;