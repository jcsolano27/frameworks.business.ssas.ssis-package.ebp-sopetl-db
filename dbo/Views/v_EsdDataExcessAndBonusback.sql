

CREATE VIEW dbo.v_EsdDataExcessAndBonusback 
/* Test Harness
	SELECT * FROM dbo.v_EsdDataExcessAndBonusback
*/
AS
	SELECT DISTINCT dbs.EsdVersionId
		,dbs.ResetWw
		,dbs.SdaFamily
		,dbs.ItemClass
		,dbs.ItemDescription
		,dph.SnOPDemandProductId
		,dph.SnOPDemandProductNm
		,dbs.YearQq
		,dbs.YearMm
		,dbs.ExcessToMpsInvTarget
		,dbs.BonusableDiscreteExcess
		,dbs.NonBonusableDiscreteExcess
		,dbs.ExcessToMpsInvTargetCum
		,dbs.BonusableCum
		,dbs.NonBonusableCum
		,dbs.Process
		,dbs.CreatedOn
		,dbs.CreatedBy
	FROM dbo.[EsdBonusableSupply] dbs (NOLOCK)
		LEFT OUTER JOIN dbo.SnOPDemandProductHierarchy dph (NOLOCK)
			ON dph.SnOPDemandProductId = dbs.SnOPDemandProductId

