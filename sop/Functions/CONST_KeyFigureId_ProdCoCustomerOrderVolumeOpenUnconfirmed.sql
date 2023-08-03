CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenUnconfirmed]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Customer Order Volume (open/unconfirmed)';
    RETURN @KeyFigureId;
END;
