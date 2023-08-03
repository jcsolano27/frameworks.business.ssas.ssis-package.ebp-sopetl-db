
CREATE FUNCTION [sop].[CONST_KeyFigureId_DemandSupportedDollars]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Demand Supported Dollars';
    RETURN @KeyFigureId;
END;
