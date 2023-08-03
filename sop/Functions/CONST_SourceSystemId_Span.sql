CREATE   FUNCTION [sop].[CONST_SourceSystemId_Span]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'SPAN';

    RETURN @SourceSystemId;
END;
