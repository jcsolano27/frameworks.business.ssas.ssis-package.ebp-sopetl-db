CREATE   FUNCTION [sop].[CONST_SourceSystemId_SapIbp]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM [sop].[SourceSystem]
    WHERE SourceSystemNm = 'SAP IBP';

    RETURN @SourceSystemId;
END;