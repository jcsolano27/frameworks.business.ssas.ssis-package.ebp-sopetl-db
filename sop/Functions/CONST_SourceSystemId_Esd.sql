CREATE FUNCTION [sop].[CONST_SourceSystemId_Esd]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;
    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'ESD';
    RETURN @SourceSystemId;
END;
