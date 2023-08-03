  
CREATE     PROC [dbo].[UspLoadSnOPDemandForecastData]  
  
AS  
/************************************************************************************    
DESCRIPTION: This proc is used to load data from Fab MPS for selected Versions    
  
----    Date  User            Description    
----***************************************************************************-    
----    2023-07-21 fgarc20x  Included Delete when data from Source don't exist on Target  
---- 2023-07-24  fgarc20x  Logic adjusted to use SnOPDemandForecastMonth on Merge  
----*********************************************************************************     
  
*************************************************************************************/   
BEGIN  
 SET NOCOUNT ON  
 DECLARE @BatchId VARCHAR(100) = 'LoadSnOPDemandForecastData.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER  
 DECLARE @EmailMessage VARCHAR(1000) ='LoadSnOPDemandForecastData Successful'  
 DECLARE @Prog VARCHAR(255)  
 DECLARE @SourceApplicationName VARCHAR(100) = 'Denodo'  
 DECLARE @CONST_ParameterId_ConsensusDemand INT = [dbo].[CONST_ParameterId_ConsensusDemand]()  
  
 BEGIN TRY  
  --Logging Start  
  EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPDemandForecastData', 'UspLoadSnOPDemandForecastData','Load Demand Forecast data', 'BEGIN', NULL, @BatchId  
  
  ;WITH CTE_DemandForecastScenarios AS   
  (  
   SELECT   
    ProfitCenterHierarchyId,   
    VersionNm,ProductNodeId,   
    FiscalYearMonthNm,  
    CASE  
     WHEN ScenarioId = 2 THEN P.ParameterId ELSE ScenarioId  
    END AS ScenarioId,  
    LastUpdateSystemDtm AS ModifiedOn,  
    CONVERT(FLOAT, ConsensusDemandForecastPublishQty) AS "QTY"  
   FROM [dbo].[StgSnOPDemandForecast]  
   JOIN [dbo].[Parameters] AS P  
   ON ParameterId = @CONST_ParameterId_ConsensusDemand  
   UNION ALL  
   SELECT   
   ProfitCenterHierarchyId,   
   VersionNm,ProductNodeId,   
   FiscalYearMonthNm,  
   ScenarioId,  
   LastUpdateSystemDtm AS ModifiedOn,  
   CONVERT(FLOAT, ConsensusDemandForecastDraftQty) AS "QTY"  
   FROM [dbo].[StgSnOPDemandForecast]  
   WHERE ScenarioId = 2  
  ),  PlanningMonths  
  AS (SELECT DISTINCT  
              CONCAT(LEFT(C.VersionNm, 4),RIGHT(C.VersionNm, 2))   as PlanningMonthNbr  
        FROM CTE_DemandForecastScenarios C  
   WHERE VersionNm NOT IN ('MONTH-1', 'CURRENT')   
 )   
    
  MERGE [dbo].[SnOPDemandForecast] as T  
  USING   
   (  
   SELECT   
    SourceApplicationName,  
    SnOPDemandForecastMonth,  
    SnOPDemandProductId,  
    ProfitCenterCd,  
    FiscalYearMonthNbr,  
    ScenarioId AS ParameterId,   
    MAX(DATEADD (ss , 1 , ModifiedOn)) AS ModifiedOn,  
    SUM(COALESCE(QTY,0)) AS QTY  
   FROM (  
    SELECT   
     @SourceApplicationName AS "SourceApplicationName",  
     PM.[PlanningMonth] AS "SnOPDemandForecastMonth",  
     I.SnOPDemandProductId,  
     PC.ProfitCenterCd,  
     CONCAT(LEFT(C.FiscalYearMonthNm, 4),RIGHT(C.FiscalYearMonthNm, 2)) AS FiscalYearMonthNbr,  
     ScenarioId,  
     ModifiedOn,  
     QTY  
    FROM CTE_DemandForecastScenarios AS C   
    JOIN  
    [dbo].[StgProfitCenterHierarchy] AS PC  
    ON PC.[ProfitCenterHierarchyId] = C.ProfitCenterHierarchyId  
    JOIN [dbo].[PlanningMonths] AS PM  
    ON PM.[PlanningMonth] = CONCAT(LEFT(C.VersionNm, 4),RIGHT(C.VersionNm, 2))  
    JOIN [dbo].[StgProductHierarchy] AS I  
    ON I.ProductNodeId = C.ProductNodeId  
    WHERE VersionNm NOT IN ('MONTH-1', 'CURRENT')  
   )  
   AS CD  
   GROUP BY   
   SourceApplicationName,  
   SnOPDemandForecastMonth,  
   SnOPDemandProductId,  
   ProfitCenterCd,  
   FiscalYearMonthNbr,  
   ScenarioId  
  )  
  AS S  
  ON  T.SourceApplicationName = S.SourceApplicationName AND  
   T.SnOPDemandForecastMonth = S.SnOPDemandForecastMonth AND  
   T.[SnOPDemandProductId] = S.SnOPDemandProductId AND  
   T.[ProfitCenterCd] = S.ProfitCenterCd AND  
   T.[YearMm] = S.FiscalYearMonthNbr AND   
   T.[ParameterId] = S.ParameterId  
  WHEN NOT MATCHED BY Target THEN  
   INSERT ([SourceApplicationName], [SnOPDemandForecastMonth], [SnOPDemandProductId], [ProfitCenterCd], [YearMm], [ParameterId], [Quantity],ModifiedOn)  
   VALUES (S.SourceApplicationName,S.SnOPDemandForecastMonth,S.SnOPDemandProductId,S.ProfitCenterCd,S.FiscalYearMonthNbr,S.ParameterId, S.QTY,ModifiedOn)  
  WHEN MATCHED THEN UPDATE SET  
   T.[Quantity] = S.QTY,  
   T.ModifiedOn = S.ModifiedOn  
   /*WHEN NOT MATCHED BY SOURCE THEN DELETE*/     
  
    WHEN NOT MATCHED BY SOURCE   
       AND T.SnOPDemandForecastMonth IN  
        (  
         SELECT PlanningMonths.PlanningMonthNbr FROM PlanningMonths  
        ) THEN  
        DELETE  
  ;  
   
  INSERT INTO [dbo].[SDRAVersion](VersionId, VersionNm)   
  SELECT DISTINCT   
  VersionId, VersionNm   
  FROM [dbo].[StgSnOPDemandForecast]   
   WHERE VersionId = (  
    SELECT   
     MAX(VersionId)   
    FROM [dbo].[StgSnOPDemandForecast]  
    )  
   AND VersionId NOT IN (  
    SELECT   
     DISTINCT VersionId   
    FROM [dbo].[SDRAVersion]  
   );  
  
  -- Update dbo.ChangeDemand   
  exec [dbo].[UspLoadChangeDemand];  
    
  --Logging End  
  
  EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPDemandForecastData', 'UspLoadSnOPDemandForecastData','Load Demand Forecast data', 'END', NULL, @BatchId  
    
  --Send sucess email to MPS Recon support PDL  
  EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject= 'LoadSnOPDemandForecastData Successful'  
  
 END TRY  
 BEGIN CATCH   
    
  --Send failure email to MPS Recon support PDL   
  SET @Prog = ERROR_PROCEDURE();  
  SET @EmailMessage='LoadSnOPDemandForecastData failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()  
  
  EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='LoadSnOPDemandForecastData Failed'  
  
  --Add Entry in Log Table  
  DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()  
  EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadSnOPDemandForecastData','UspLoadSnOPDemandForecastData', 'Load Demand Forecast data','ERROR', @ErrorMsg, @BatchId  
  
  RAISERROR(@ErrorMsg, 16, 1)  
 END CATCH  
   
 SET NOCOUNT OFF  
END