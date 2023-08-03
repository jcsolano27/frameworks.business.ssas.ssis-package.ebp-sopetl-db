
CREATE FUNCTION [sop].[CONST_KeyFigureId_GrossBillingVolume]
()
RETURNS INT
AS
BEGIN

    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Gross Billing Volume';
    RETURN @KeyFigureId;
END;
