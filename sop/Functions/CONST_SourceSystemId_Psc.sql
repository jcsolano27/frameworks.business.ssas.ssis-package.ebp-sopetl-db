CREATE   FUNCTION [sop].[CONST_SourceSystemId_Psc]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'PSC';

    RETURN @SourceSystemId;
END;
