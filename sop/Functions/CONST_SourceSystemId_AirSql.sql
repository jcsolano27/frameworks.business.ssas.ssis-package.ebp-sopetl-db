CREATE   FUNCTION [sop].[CONST_SourceSystemId_AirSql]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'AirSQL';

    RETURN @SourceSystemId;
END;
