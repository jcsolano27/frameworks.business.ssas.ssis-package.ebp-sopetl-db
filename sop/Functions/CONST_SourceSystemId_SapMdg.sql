CREATE FUNCTION [sop].[CONST_SourceSystemId_SapMdg]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM [sop].[SourceSystem]
    WHERE SourceSystemNm = 'SAP MDG';

    RETURN @SourceSystemId;
END;
