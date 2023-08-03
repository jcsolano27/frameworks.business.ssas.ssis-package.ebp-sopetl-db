CREATE FUNCTION [sop].[CONST_KeyFigureId_SourceKeyFigureNm]
(
    @SourceKeyFigureNm VARCHAR(50)
)
RETURNS INT
AS
BEGIN

    DECLARE @KeyFigureId INT = 0;

    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE SourceKeyFigureNm = @SourceKeyFigureNm;

    RETURN @KeyFigureId;
END;