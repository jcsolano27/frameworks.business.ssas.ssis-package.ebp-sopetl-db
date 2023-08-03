----              
----    Purpose:        This proc is used to load [sop].[PlanVersion] data              
----                    Destination: [sop].[PlanVersion]              
----    Called by:      SSIS              
----              
----    Result sets:    None              
----              
----    Date		User            Description              
----****************************************************************************************************************************************              
----	2023-07-19	caiosanx		Initial Release              
----	2023-07-24	fjunio2x		Inserted ESD POR change version    
----    2023-08-01	fjunio2x		Check if the version is Uncontrained based on EsdVersionName  
----    2023-08-02	fjunio2x        Created a new parameter @Operation to indicate what the procedure have to do with an EsdVersion  
----    2023-08-02	fjunio2x        Created a new logic to apply delete (logical)  
----    2023-08-03	caiosanx        Changed rev opt PlanVersionCategoryCd value
----****************************************************************************************************************************************/             

/*      
TEST HARNESS:      
      
DECLARE @KeyFigureId INT = [sop].[CONST_KeyFigureId_ProdCoRevenueVolume]();      
      
EXEC sop.UspLoadPlanVersion @KeyFigureId = @KeyFigureId;      
  
EXEC sop.UspLoadPlanVersion @Operation = 'I', @EsdVersion = @EsdVersion;      
  
EXEC sop.UspLoadPlanVersion @Operation = 'D', @EsdVersion = @EsdVersion;      
*/

CREATE PROC [sop].[UspLoadPlanVersion]
    @KeyFigureId INT = 0,
    @Operation VARCHAR(1) = NULL, -- 'I' - Insert/Update / 'D' - Delete (logical)  
    @EsdVersionId INT = NULL
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

DECLARE @CONST_KeyFigureId_ProdCoRevenueVolume INT = [sop].[CONST_KeyFigureId_ProdCoRevenueVolume](),
        @CONST_KeyFigureId_ProdCoRevenueDollars INT = [sop].[CONST_KeyFigureId_ProdCoRevenueDollars](),
        @CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt INT = [sop].[CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt](),
        @CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt INT = [sop].[CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt](),
        @CONST_KeyFigureId_TmgfActualCommitCapacity INT = [sop].[CONST_KeyFigureId_TmgfActualCommitCapacity](),
        @CONST_KeyFigureId_TmgfActualEquippedCapacity INT = [sop].[CONST_KeyFigureId_TmgfActualEquippedCapacity]();

DECLARE @PlanVersionNm VARCHAR(40),
        @PlanVersionDsc VARCHAR(100),
        @SourcePlanningMonthNbr INT,
        @ScenarioId INT,
        @ConstrainedId INT,
        @SourceSystemId INT,
        @SourceVersionId INT,
        @PlanVersionId INT,
        @PlanVersionCategoryCd CHAR(3);

-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
-- FINANCE POR VERSION      
-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
IF @KeyFigureId IN ( @CONST_KeyFigureId_ProdCoRevenueVolume, @CONST_KeyFigureId_ProdCoRevenueDollars, 999 )
BEGIN
    SELECT DISTINCT
           @PlanVersionNm = VersionNm,
           @PlanVersionDsc = CONCAT(LEFT(VersionNm, 4), ' BASE'),
           @SourcePlanningMonthNbr = [sop].[fnGetPlanningMonthVersionNm](LEFT(VersionNm, 4)),
           @ScenarioId = sop.CONST_ScenarioId_Base(),
           @SourceSystemId = sop.CONST_SourceSystemId_SapIbp(),
           @PlanVersionCategoryCd = 'REV',
           @SourceVersionId = VersionId
    FROM sop.StgRevenueForecast
    WHERE EtlOrigin = 'RevenuePor';

    IF NOT EXISTS
    (
        SELECT *
        FROM sop.PlanVersion
        WHERE PlanVersionNm = @PlanVersionNm
    )
    BEGIN
        INSERT sop.PlanVersion
        (
            PlanVersionNm,
            PlanVersionDsc,
            ScenarioId,
            SourcePlanningMonthNbr,
            ActiveInd,
            SourceSystemId,
            SourceVersionId,
            CreatedOnDtm,
            CreatedByNm,
            ModifiedOnDtm,
            ModifiedByNm,
            PlanVersionCategoryCd
        )
        VALUES
        (@PlanVersionNm, @PlanVersionDsc, @ScenarioId, @SourcePlanningMonthNbr, 1, @SourceSystemId, @SourceVersionId,
         DEFAULT, DEFAULT, DEFAULT, DEFAULT, @PlanVersionCategoryCd);
    END;
END;

-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
-- REV OPT VERSION      
-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
IF @KeyFigureId IN ( @CONST_KeyFigureId_ProdCoRevenueVolumeRevOpt, @CONST_KeyFigureId_ProdCoRevenueDollarsRevOpt, 999 )
BEGIN
    SELECT @PlanVersionNm = CONCAT('Finance RevOpt ', FiscalYearMonthNbr, ' ', WorkWeekNm),
           @PlanVersionDsc = CONCAT('Finance RevOpt version for ', FiscalYearMonthNbr, ' ', WorkWeekNm),
           @SourceSystemId = sop.CONST_SourceSystemId_SapIbp(),
           @SourcePlanningMonthNbr = FiscalYearMonthNbr,
           @ScenarioId = sop.CONST_ScenarioId_Base()
    FROM sop.TimePeriod
    WHERE SourceNm = 'WorkWeek'
          AND GETDATE()
          BETWEEN StartDt AND EndDt;

    IF NOT EXISTS
    (
        SELECT *
        FROM sop.PlanVersion
        WHERE PlanVersionNm = @PlanVersionNm
    )
    BEGIN
        INSERT sop.PlanVersion
        (
            PlanVersionNm,
            PlanVersionDsc,
            ScenarioId,
            SourcePlanningMonthNbr,
            ActiveInd,
            SourceSystemId,
            CreatedOnDtm,
            CreatedByNm,
            ModifiedOnDtm,
            ModifiedByNm,
            PlanVersionCategoryCd
        )
        VALUES
        (@PlanVersionNm, @PlanVersionDsc, @ScenarioId, @SourcePlanningMonthNbr, 1, @SourceSystemId, DEFAULT, DEFAULT,
         DEFAULT, DEFAULT, 'RVO');
    END;
END;

-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
-- REV OPT VERSION      
-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
IF @KeyFigureId IN ( @CONST_KeyFigureId_TmgfActualCommitCapacity, @CONST_KeyFigureId_TmgfActualEquippedCapacity, 999 )
BEGIN
    SET @SourceVersionId =
    (
        SELECT MAX(PublishLogId)FROM SVD.[dbo].[SnOPCompassMRPFabRouting]
    );

    SET @PlanVersionNm =
    (
        SELECT ScenarioNm
        FROM sop.CapacitySourceVersion
        WHERE PublishLogId = @SourceVersionId
    );

    SET @ScenarioId = sop.CONST_ScenarioId_NotApplicable();

    SET @SourceSystemId = sop.CONST_SourceSystemId_Svd();

    IF NOT EXISTS
    (
        SELECT *
        FROM sop.PlanVersion
        WHERE @PlanVersionNm = PlanVersionNm
    )
    BEGIN
        INSERT sop.PlanVersion
        (
            PlanVersionNm,
            PlanVersionDsc,
            ScenarioId,
            SourceVersionId,
            ActiveInd,
            SourceSystemId
        )
        VALUES
        (@PlanVersionNm, @PlanVersionNm, @ScenarioId, @SourceVersionId, 1, @SourceSystemId);
    END;
END;

-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
-- ESD POR VERSION      
-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------*-------------      
IF @EsdVersionId IS NOT NULL
BEGIN
    IF @Operation = 'I' -- Insert or Update a PlanVersion  
    BEGIN
        MERGE [sop].[PlanVersion] T
        USING
        (
            SELECT Esd.EsdVersionId,
                   Esd.EsdVersionName,
                   Pmt.PlanningMonth,
                   Esd.IsPrePORExt,
                   ISNULL(Esd.PublishedOn, Esd.CreatedOn) PublishedOn,
                   ISNULL(Esd.PublishedBy, Esd.CreatedBy) PublishedBy
            FROM [dbo].[EsdVersions] Esd
                JOIN [dbo].[EsdBaseVersions] Ebv
                    ON Ebv.EsdBaseVersionId = Esd.EsdBaseVersionId
                JOIN [dbo].[PlanningMonths] Pmt
                    ON Pmt.PlanningMonthId = Ebv.PlanningMonthId
            WHERE (
                      Esd.IsPOR = 1
                      OR Esd.IsPrePORExt = 1
                      OR Esd.EsdVersionName LIKE '%UNCONSTRAINED%'
                  )
                  AND Esd.EsdVersionId = @EsdVersionId
        ) S
        ON S.EsdVersionId = T.SourceVersionId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                [PlanVersionNm],
                [PlanVersionDsc],
                [PlanVersionCategoryCd],
                [ScenarioId],
                [ConstraintCategoryId],
                [SourceVersionId],
                [SourcePlanningMonthNbr],
                [ActiveInd],
                [SourceSystemId],
                [CreatedOnDtm],
                [CreatedByNm],
                [ModifiedOnDtm],
                [ModifiedByNm]
            )
            VALUES
            (S.EsdVersionName, S.EsdVersionName, 'SUP', sop.CONST_ScenarioId_Base(),
             IIF(S.IsPrePORExt = 1,
                 sop.CONST_ConstraintCategoryId_Unconstrained(),
                 sop.CONST_ConstraintCategoryId_FabConstrained()), S.EsdVersionId, S.PlanningMonth, 1,
             sop.CONST_SourceSystemId_Esd(), S.PublishedOn, S.PublishedBy, S.PublishedOn, S.PublishedBy)
        WHEN MATCHED AND T.ModifiedOnDtm < S.PublishedOn
                         OR T.ActiveInd = 0 THEN
            UPDATE SET T.ActiveInd = 1,
                       T.ModifiedOnDtm = S.PublishedOn,
                       T.ModifiedByNm = S.PublishedBy;
    END;
    ELSE IF @Operation = 'D' -- Logical Delete of a PlanVersion  
    BEGIN
        UPDATE sop.PlanVersion
        SET ActiveInd = 0,
            ModifiedOnDtm = SYSDATETIME(),
            ModifiedByNm = ORIGINAL_LOGIN()
        WHERE SourceVersionId = @EsdVersionId
              AND ConstraintCategoryId <> sop.CONST_ConstraintCategoryId_Unconstrained();
    END;

END;