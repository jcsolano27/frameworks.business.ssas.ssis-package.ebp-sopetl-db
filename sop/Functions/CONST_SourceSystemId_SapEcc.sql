CREATE   FUNCTION [sop].[CONST_SourceSystemId_SapEcc]
()
RETURNS INT
AS
BEGIN
    DECLARE @SourceSystemId INT = 0;

    SELECT @SourceSystemId = SourceSystemId
    FROM sop.SourceSystem
    WHERE SourceSystemNm = 'SAP ECC';

    RETURN @SourceSystemId;
END;
