CREATE   FUNCTION [sop].[CONST_ProfitCenterCd_NotApplicable]()
RETURNS INT
AS
BEGIN
    DECLARE @ProfitCenterCd INT = 0;
    
	SELECT @ProfitCenterCd = ProfitCenterCd
    FROM sop.ProfitCenter
    WHERE ProfitCenterNm = 'N/A';
    
	RETURN @ProfitCenterCd;
END;
