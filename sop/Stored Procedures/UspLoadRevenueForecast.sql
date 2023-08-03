
----        
----    Purpose:        This proc is used to load [sop].[RevenueForecast] data        
----                    Source:      [sop].[StgRevenuePor] | [sop].[StgRevenueRevOpt]         
----                    Destination: [sop].[RevenueForecast]        
----    Called by:      SSIS        
----        
----    Result sets:    None        
----        
----    Date		User            Description        
----*********************************************************************************        
----	2023-06-21  caiosanx		Initial Release
----    2023-08-02	psillosx		Quantity is not null and <> 0        
----*********************************************************************************/        

CREATE PROC [sop].[UspLoadRevenueForecast]
(
    @SourceVersionId INT,
    @KeyFigureId INT
)
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

-- POR KeyFigureId
DECLARE @CONST_KeyFigureId_ProdCoRevenueVolume INT = [sop].[CONST_KeyFigureId_ProdCoRevenueVolume](),
        @CONST_KeyFigureId_ProdCoRevenueDollars INT = [sop].[CONST_KeyFigureId_ProdCoRevenueDollars]();

-- RevOpt KeyFigureId
DECLARE @CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt INT = [sop].[CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt](),
        @CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt INT = [sop].[CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt]();

DECLARE @PlanVersionNm VARCHAR(40),
        @PlanVersionDsc VARCHAR(100),
        @SourcePlanningMonthNbr INT,
        @ScenarioId INT,
        @SourceSystemId INT = sop.CONST_SourceSystemId_SapIbp(),
        @PlanVersionId INT,
        @PlanVersionCategoryCd CHAR(3) = 'REV';

IF @KeyFigureId IN ( @CONST_KeyFigureId_ProdCoRevenueVolume, @CONST_KeyFigureId_ProdCoRevenueDollars, 999 )
BEGIN
    MERGE sop.RevenueForecast T
    USING
    (
        SELECT
            PlanningMonthNbr,
            PlanVersionId,
            ProductId,
            ProfitCenterCd,
            KeyFigureId,
            TimePeriodId,
            Quantity
        FROM (
            SELECT Q.PlanningMonthNbr,
                [sop].[CONST_PlanVersionId_SourceVersionIdScenarioId](Q.SourceVersionid, Q.ScenarioId) PlanVersionId,
                Q.ProductId,
                Q.ProfitCenterCd,
                Q.KeyFigureId,
                Q.TimePeriodId,
                SUM(Q.Quantity) Quantity
            FROM (
                SELECT [sop].[fnGetPlanningMonthVersionNm](LEFT(VersionNm, 4)) PlanningMonthNbr,
                    [sop].[CONST_ProductId_ProductNodeId](ProductNodeId) ProductId,
                    ProfitCenterCd,
                    VersionId SourceVersionid,
                    [sop].[CONST_Scenario](RIGHT(ScenarioNm, 4)) ScenarioId,
                    [sop].[CONST_KeyFigureId_SourceKeyFigureNm](SourceKeyFigureNm) KeyFigureId,
                    [sop].[CONST_TimePeriodId_SourceTimePeriodId](FiscalCalendarId) TimePeriodId,
                    Quantity
                FROM sop.StgRevenueForecast
                UNPIVOT
                (
                    Quantity
                    FOR SourceKeyFigureNm IN (BusinessUnitFinancePlanOfRecordAmt, BusinessUnitFinancePlanOfRecordQty)
                ) U
                WHERE EtlOrigin = 'RevenuePor'
            ) Q
            GROUP BY [sop].[CONST_PlanVersionId_SourceVersionIdScenarioId](Q.SourceVersionid, Q.ScenarioId),
                Q.PlanningMonthNbr,
                Q.ProductId,
                Q.ProfitCenterCd,
                Q.KeyFigureId,
                Q.TimePeriodId
        ) AS GroupBy
        WHERE Quantity IS NOT null
            AND Quantity <> 0
    ) S
    ON S.PlanningMonthNbr = T.PlanningMonthNbr
       AND S.PlanVersionId = T.PlanVersionId
       AND S.ProductId = T.ProductId
       AND S.ProfitCenterCd = T.ProfitCenterCd
       AND S.KeyFigureId = T.KeyFigureId
       AND S.TimePeriodId = T.TimePeriodId
    WHEN NOT MATCHED BY TARGET THEN
        INSERT
        (
            PlanningMonthNbr,
            PlanVersionId,
            ProductId,
            ProfitCenterCd,
            KeyFigureId,
            TimePeriodId,
            Quantity,
            CreatedOnDtm,
            CreatedByNm,
            ModifiedOnDtm,
            ModifiedByNm
        )
        VALUES
        (S.PlanningMonthNbr, S.PlanVersionId, S.ProductId, S.ProfitCenterCd, S.KeyFigureId, S.TimePeriodId, S.Quantity,
         DEFAULT, DEFAULT, DEFAULT, DEFAULT)
    WHEN MATCHED AND S.Quantity <> T.Quantity THEN
        UPDATE SET T.Quantity = S.Quantity,
                   T.ModifiedOnDtm = GETDATE(),
                   T.ModifiedByNm = ORIGINAL_LOGIN()
    WHEN NOT MATCHED BY SOURCE AND T.PlanVersionId = @PlanVersionId
                                   AND T.KeyFigureId IN ( @CONST_KeyFigureId_ProdCoRevenueDollars,
                                                          @CONST_KeyFigureId_ProdCoRevenueVolume
                                                        ) THEN
        DELETE;
END;

IF @KeyFigureId IN ( @CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt, @CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt, 999 )
BEGIN
    SELECT @PlanVersionNm = CONCAT('Finance RevOpt ', FiscalYearMonthNbr, ' ', WorkWeekNm),
           @SourcePlanningMonthNbr = FiscalYearMonthNbr
    FROM sop.TimePeriod
    WHERE SourceNm = 'WorkWeek'
          AND GETDATE()
          BETWEEN StartDt AND EndDt;

    SET @PlanVersionId =
    (
        SELECT PlanVersionId
        FROM sop.PlanVersion
        WHERE PlanVersionNm = @PlanVersionNm
    );

    MERGE sop.RevenueForecast T
    USING
    (
        SELECT
            ProfitCenterCd,
            KeyFigureId,
            TimePeriodId,
            Quantity
        FROM (
            SELECT Q.ProfitCenterCd,
                Q.KeyFigureId,
                Q.TimePeriodId,
                SUM(Q.Quantity) Quantity
            FROM (
                SELECT ISNULL(ProfitCenterCd, 0) ProfitCenterCd,
                    [sop].[CONST_KeyFigureId_SourceKeyFigureNm](SourceKeyFigureNm) KeyFigureId,
                    [sop].[CONST_TimePeriodId_SourceTimePeriodId](FiscalCalendarId) TimePeriodId,
                    Quantity
                FROM sop.StgRevenueForecast
                UNPIVOT
                (
                    Quantity
                    FOR SourceKeyFigureNm IN (RevOptQty, RevOptAmt)
                ) U
                WHERE EtlOrigin = 'RevenueRevOpt'
            ) Q
            GROUP BY Q.ProfitCenterCd,
                Q.KeyFigureId,
                Q.TimePeriodId
        ) AS GroupBy
        WHERE Quantity IS NOT NULL
            AND Quantity <> 0
    ) S
    ON S.ProfitCenterCd = T.ProfitCenterCd
       AND S.KeyFigureId = T.KeyFigureId
       AND S.TimePeriodId = T.TimePeriodId
    WHEN NOT MATCHED BY TARGET THEN
        INSERT
        (
            ProfitCenterCd,
            KeyFigureId,
            TimePeriodId,
            PlanVersionId,
            PlanningMonthNbr,
            Quantity
        )
        VALUES
        (S.ProfitCenterCd, S.KeyFigureId, S.TimePeriodId, @PlanVersionId, @SourcePlanningMonthNbr, S.Quantity)
    WHEN MATCHED AND S.Quantity <> T.Quantity THEN
        UPDATE SET T.Quantity = S.Quantity,
                   T.ModifiedOnDtm = GETDATE(),
                   T.ModifiedByNm = ORIGINAL_LOGIN()
    WHEN NOT MATCHED BY SOURCE AND T.PlanVersionId = @PlanVersionId
                                   AND T.KeyFigureId IN ( @CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt,
                                                          @CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt
                                                        ) THEN
        DELETE;
END;
