CREATE   FUNCTION [sop].[CONST_SourceSystemId_Profisee]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'Profisee';

    RETURN @SourceSystemId;
END;