
CREATE PROCEDURE [dbo].[uspReportSvdFetchDimSourceVersion]
(
    @Debug BIT = 0,
    @PlanningMonthCurr INT,
    @PlanningMonthPrev INT
)
AS
BEGIN
    /*  TEST HARNESS
        EXECUTE [dbo].[uspReportSvdFetchDimSourceVersion] 1, 202208, 202207
    */

    DECLARE @NonSupplyVersionType VARCHAR(100) = 'N/A', @NonSupplyVersionNm VARCHAR(100) = 'Drain'

    SELECT DISTINCT v.SvdSourceVersionId, v.PlanningMonth, 
        v.SvdSourceApplicationId, a.SvdSourceApplicationName, 
        IIF(v.SourceVersionType = @NonSupplyVersionType, @NonSupplyVersionNm, v.SourceVersionType) AS SourceVersionType, v.SourceVersionId,
        IIF(v.SourceVersionType = @NonSupplyVersionType, '', a.SvdSourceApplicationName + ' (' + CAST(v.SourceVersionId AS VARCHAR(7)) + ') ') 
        + 
        IIF(v.SourceVersionType = @NonSupplyVersionType, @NonSupplyVersionNm, v.SourceVersionNm) AS SourceVersionNm 
    FROM dbo.SvdSourceVersion v
        INNER JOIN dbo.SvdSourceApplications a
            ON v.SvdSourceApplicationId = a.SvdSourceApplicationId
        INNER JOIN dbo.SvdOutput o
            ON v.SvdSourceVersionId = o.SvdSourceVersionId
    WHERE v.PlanningMonth IN (@PlanningMonthCurr, @PlanningMonthPrev)
    ORDER BY PlanningMonth, SourceVersionId

END
