CREATE FUNCTION [sop].[CONST_KeyFigureId_IqmExcessInventory]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'IQM Excess Inventory';
    RETURN @KeyFigureId;
END;
