CREATE PROC [sop].[UspLoadProdCoRequestVolumeFeCbf]
AS

----/*********************************************************************************    
---- Source:                     sop.[PlanningFigure] - KeyFigureNm = TMGF Supply Response Volume/FE           
---- Purpose:                    Load data to sop.[PlanningFigure] | KeyFigureNm =  ProdCo Request Volume/FE/CBF

----    Date        User            Description    
----***************************************************************************-    
----	2023-07-12	vitorsix        Initial Release    
----*********************************************************************************/    
SET NOCOUNT ON;

DECLARE @CurrentPlanningMonth INT =
        (
            SELECT PlanningMonthEndNbr FROM sop.fnGetReportPlanningMonthRange()
        );

DECLARE @PreviousPlanningMonth INT =
        (
            SELECT FiscalYearMonthNbr
            FROM [sop].[TimePeriod]
            WHERE MonthSequenceNbr =
                (
                    SELECT MonthSequenceNbr
                    FROM [sop].[TimePeriod]
                    WHERE FiscalYearMonthNbr = @CurrentPlanningMonth
                          AND SourceNm = 'Month'
                ) - 1
                  AND SourceNm = 'Month'
        );

DECLARE @KeyFigureIdProdCoRequestVolumefeCbf INT = [sop].[CONST_KeyFigureId_ProdCoRequestVolumeFeCbf](),
        @KeyFigureIdTmgfSupplyResponseVolumeFe INT = [sop].[CONST_KeyFigureId_TmgfSupplyResponseVolumeFe]();

		

MERGE [sop].[PlanningFigure] T
USING
(
    SELECT @CurrentPlanningMonth AS PlanningMonthNbr,
           PF.[PlanVersionId],
           PF.CorridorId,
           PF.ProductId,
           PF.ProfitCenterCd,
           PF.CustomerId,
           @KeyFigureIdProdCoRequestVolumefeCbf [KeyFigureId],
           PF.TimePeriodId,
           PF.Quantity
    FROM [SVD].[sop].[PlanningFigure] PF
        JOIN sop.PlanVersion PV
            ON PV.ConstraintCategoryId = 2
               AND PF.PlanningMonthNbr = PV.SourcePlanningMonthNbr
               AND PF.PlanVersionId = PV.PlanVersionId
    WHERE KeyFigureId = @KeyFigureIdTmgfSupplyResponseVolumeFe
          AND PF.PlanningMonthNbr = @PreviousPlanningMonth
) S
ON T.PlanningMonthNbr = S.PlanningMonthNbr
   AND T.PlanVersionId = S.PlanVersionId
   AND T.CorridorId = S.CorridorId
   AND T.ProductId = S.ProductId
   AND T.ProfitCenterCd = S.ProfitCenterCd
   AND T.CustomerId = S.CustomerId
   AND T.KeyFigureId = S.KeyFigureId
   AND T.TimePeriodId = S.TimePeriodId
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        PlanningMonthNbr,
        PlanVersionId,
        CorridorId,
        ProductId,
        ProfitCenterCd,
        CustomerId,
        KeyFigureId,
        TimePeriodId,
        Quantity
    )
    VALUES
    (S.PlanningMonthNbr, S.PlanVersionId, S.CorridorId, S.ProductId, S.ProfitCenterCd, S.CustomerId, S.KeyFigureId,
     S.TimePeriodId, S.Quantity)
WHEN MATCHED AND S.Quantity <> T.Quantity THEN
    UPDATE SET T.Quantity = S.Quantity,
               T.ModifiedOnDtm = GETDATE(),
               T.ModifiedByNm = ORIGINAL_LOGIN();