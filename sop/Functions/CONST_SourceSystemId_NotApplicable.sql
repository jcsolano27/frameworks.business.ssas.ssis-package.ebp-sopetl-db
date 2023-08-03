CREATE FUNCTION [sop].[CONST_SourceSystemId_NotApplicable]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;
    SELECT @SourceSystemId = SourceSystemId
    FROM [sop].[SourceSystem]
    WHERE SourceSystemNm = 'N/A';
    RETURN @SourceSystemId;
END;
