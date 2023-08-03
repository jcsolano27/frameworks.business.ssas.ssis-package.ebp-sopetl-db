
CREATE VIEW dbo.v_EsdVersionsPOR
AS 
	WITH PorSelect
	AS
    (
		SELECT
				v.EsdVersionId
				, v.EsdBaseVersionId
				, v.IsPOR
				, v.IsPrePORExt
				, v.PublishedOn
				, v.PublishedBy
				, m.PlanningMonth
				, RowNum = ROW_NUMBER() OVER (PARTITION BY v.EsdBaseVersionId ORDER BY v.IsPOR DESC, v.IsPrePORExt DESC, v.EsdVersionId DESC)
		FROM	dbo.EsdVersions v
				INNER JOIN dbo.EsdBaseVersions bv
					ON bv.EsdBaseVersionId = v.EsdBaseVersionId
				INNER JOIN dbo.PlanningMonths m
					ON m.PlanningMonthId = bv.PlanningMonthId
		WHERE v.IsPOR = 1 OR v.IsPrePORExt = 1
    )
	SELECT por.EsdVersionId
		   , por.EsdBaseVersionId
		   , por.PlanningMonth
		   , por.IsPOR
		   , por.IsPrePORExt
		   , por.PublishedOn
		   , por.PublishedBy
		   , por.RowNum
	FROM	PorSelect por
	WHERE	por.RowNum = 1;

