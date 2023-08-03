CREATE FUNCTION [sop].[CONST_CorridorId_NotApplicable]
()
RETURNS INT
AS
BEGIN
    DECLARE @CorridorId INT = 0;

    SELECT @CorridorId = CorridorId
    FROM sop.Corridor
    WHERE CorridorNm = 'N/A';

    RETURN @CorridorId;
END;