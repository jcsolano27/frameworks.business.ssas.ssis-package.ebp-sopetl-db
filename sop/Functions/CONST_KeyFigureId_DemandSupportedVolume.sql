CREATE FUNCTION [sop].[CONST_KeyFigureId_DemandSupportedVolume]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Demand Supported Volume';
    RETURN @KeyFigureId;
END;
