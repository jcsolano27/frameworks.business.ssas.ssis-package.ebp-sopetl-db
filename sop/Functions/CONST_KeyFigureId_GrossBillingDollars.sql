
CREATE FUNCTION [sop].[CONST_KeyFigureId_GrossBillingDollars]
()
RETURNS INT
AS
BEGIN

    DECLARE @KeyFigureId INT = 0;
    SELECT @KeyFigureId = KeyFigureId
    FROM sop.KeyFigure
    WHERE KeyFigureNm = 'Gross Billing Dollars';
    RETURN @KeyFigureId;
END;
