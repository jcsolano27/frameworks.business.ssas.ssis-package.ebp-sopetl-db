CREATE   FUNCTION [sop].[CONST_SourceSystemId_ICost]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'ICOST';

    RETURN @SourceSystemId;
END;