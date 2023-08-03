CREATE FUNCTION [sop].[CONST_SourceSystemId_Compass]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;
    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'Compass';
    RETURN @SourceSystemId;
END;
