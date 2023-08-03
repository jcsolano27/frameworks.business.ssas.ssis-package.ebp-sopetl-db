
CREATE FUNCTION [dbo].[fnGetSnOPDemandProductsByMarketingCodeNm](@MarketingCodeNamesList VARCHAR(1000))

RETURNS @SnOPDemandProductId TABLE(SnOPDemandProductId INT, PRIMARY KEY(SnOPDemandProductId))
AS
BEGIN
/* Testing harness
	select * from dbo.[fnGetSnOPDemandProductsByMarketingCodeNm]('Alder Lake')
--*/
    DECLARE @NotApplicableSnOPDemandProductId INT = [dbo].[CONST_SnOPDemandProductId_NotApplicable]()

    --  Get MarketingCodeNm's to Load
    ----------------------------------   
    IF TRIM(COALESCE(@MarketingCodeNamesList, '')) <> ''
        BEGIN  -- List of MarketingCodeNm's provided (only get products for these)
            DECLARE @MarketingCodeNm TABLE(MarketingCodeNm VARCHAR(100))
            INSERT @MarketingCodeNm
            SELECT value FROM STRING_SPLIT(@MarketingCodeNamesList, ',')

            INSERT @SnOPDemandProductId VALUES(@NotApplicableSnOPDemandProductId) -- bull/bear forecasts don't have a product id
            INSERT @SnOPDemandProductId
            SELECT DISTINCT SnOPDemandProductId
            FROM dbo.SnOPDemandProductHierarchy dp
                INNER JOIN @MarketingCodeNm mcn
                    ON dp.MarketingCodeNm = mcn.MarketingCodeNm
        END
    ELSE    -- No limit on MarketingCodeNm's (get all products)
        BEGIN
            INSERT @SnOPDemandProductId
            SELECT SnOPDemandProductId FROM dbo.SnOPDemandProductHierarchy
        END

    RETURN
END
