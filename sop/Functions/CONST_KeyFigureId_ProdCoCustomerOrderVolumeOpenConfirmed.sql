CREATE FUNCTION [sop].[CONST_KeyFigureId_ProdCoCustomerOrderVolumeOpenConfirmed]
()
RETURNS INT
AS
BEGIN
    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'ProdCo Customer Order Volume (open/confirmed)';
    RETURN @KeyFigureId;
END;

