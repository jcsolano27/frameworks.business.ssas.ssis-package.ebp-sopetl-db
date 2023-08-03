CREATE   FUNCTION [sop].[CONST_SourceSystemId_Wspw]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'WSPW';

    RETURN @SourceSystemId;
END;
