
--select * from [dbo].[v_EsdVersions]

CREATE VIEW [dbo].[v_EsdVersions]
AS
SELECT	m.PlanningMonth, m.PlanningMonthDisplayName, m.ResetWw, bv.EsdBaseVersionId, bv.EsdBaseVersionName, 
		v.EsdVersionId, v.EsdVersionName, v.Description, v.EsdBaseVersionId AS Expr1, v.RetainFlag, v.IsPOR, v.CreatedOn, v.CreatedBy
		, v.IsPrePOR, v.IsPrePORExt
FROM    dbo.EsdVersions AS v 
		INNER JOIN dbo.EsdBaseVersions AS bv ON bv.EsdBaseVersionId = v.EsdBaseVersionId 
		INNER JOIN dbo.PlanningMonths AS m ON m.PlanningMonthId = bv.PlanningMonthId
