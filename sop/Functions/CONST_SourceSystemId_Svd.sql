﻿CREATE FUNCTION [sop].[CONST_SourceSystemId_Svd]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;
    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'SvD';
    RETURN @SourceSystemId;
END;
