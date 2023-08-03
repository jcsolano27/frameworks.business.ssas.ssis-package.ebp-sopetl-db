/*********************************************************************************  
    Author:         Steve Liu  
    Purpose:        Stitching Actual Supply with MPS Supply forecast to be used by ESD SOS Dashboard.  
     This version is used to re-stitch the target Esd version when copied from a older month ESD version.  
     It will NOT update [esd].[EsdDataSupplyStitch] table, but will update [esd].[EsdDataSupplyStitchSnapshot].  
     The original reason to create this version is for July 2021 Corp Op.  
  
    Called by:      Esd UI  
    Result sets:    None  
    Parameters:    
                    @Debug:  
      0 - No Debug output  
                        1 - Will output some basic info with timestamps  
           
    Return Codes:   0   = Success  
                    < 0 = Error  
                    > 0 (No warnings for this SP, should never get a returncode > 0)  
       
    Exceptions:     None expected  
       
    Date        User      Description  
***************************************************************************-  
    2021-06-21  Steve Liu  Initial Release  
    2021-09-14 Ben Sala  Adding extra flags for copying to master stitch
	2023-07-27	fgarc20x	Removed WFDS reference
*********************************************************************************/  
  
  
CREATE   PROCEDURE dbo.UspLoadEsdSupplyByFgWeek_CorpOp  
 @EsdVersionId_Curr INT   
 , @EsdVersionId_Prev INT   
 , @StitchYearWw_Curr INT = NULL   
 , @BatchId VARCHAR(MAX) = NULL  
 , @Debug BIT = 0  
 , @IncludeMasterStitch BIT = 0  
AS  
BEGIN  
/* Test Harness  
 exec dbo.UspLoadEsdSupplyByFgWeek_CorpOp @EsdVersionId_Curr = 160, @EsdVersionId_Prev = 152, @StitchYearWw_Curr = 202241, @Debug = 1   
  
 EXEC dbo.UspLoadEsdSupplyByDpWeek @EsdVersionId = 160;  
 EXEC [dbo].[UspLoadEsdTotalSupplyAndDemandByDpWeek] @EsdVersionId = 160;  
 EXEC dbo.UspLoadSupplyDistribution @SupplySourceTable='dbo.EsdTotalSupplyAndDemandByDpWeek',  @SourceVersionId = 160  
  
 SELECT * FROM dbo.EsdSupplyByFgWeek where ItemName = '999H22' order by 1,2  
 select EsdVersionId, LastStitchYearWw, count(*) from [dbo].[EsdSupplyByFgWeekSnapshot] group by EsdVersionId, LastStitchYearWw  
--*/  
/*--------------------------------------------------------------------------  
MAIN LOGIC:  
1. Declare Temporary table structure and scalar variables.  
1a. Update the Item List in needed for the respective runs  
2. Fetch previous stitch result from dbo.EsdSupplyByFgWeek, which are relevant for the current exectuion.  
3. Fetch data for Current and Future Weeks FROM the respective DB tables  
4. Aggregate data for Current and Future Weeks FROM section 3 and add populate the calculated fields   
5. Store specific data FROM section 3 and 4 which will be used later on for Actual calcautions   
6. Fetch data for Past Weeks FROM the respective DB tables  
7. Aggregate data for Past Weeks FROM section 6 and add populate the calculated fields   
8. Supply Delta Calculation  
9. Update Current and Future data to dbo.EsdSupplyByFgWeek  
10. Fetch Supply Excess FROM dbo.EsdSupplyByFgWeek for YearWw = @StartYearWw_Prev  
11. Update Past data to dbo.EsdSupplyByFgWeek  
-----------------------------------------------------------------------------  
*/  
 SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;  
 SET NUMERIC_ROUNDABORT OFF;   
  
 BEGIN TRY  
   --Error and transaction handling setup ********************************************************  
  DECLARE  
   @ReturnErrorMessage VARCHAR(MAX)  
   , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)  
   , @CurrentAction      VARCHAR(4000)  
   , @DT                 VARCHAR(50) = (SELECT SYSDATETIME());  
  
  SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';  
  
  IF(@BatchId IS NULL) SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();  
   
  EXEC dbo.UspAddApplicationLog  
   @LogSource = 'Database'  
   , @LogType = 'Info'  
   , @Category = @ErrorLoggedBy  
   , @SubCategory = @ErrorLoggedBy  
   , @Message = @CurrentAction  
   , @Status = 'BEGIN'  
   , @Exception = NULL  
   , @BatchId = @BatchId;  
  
  
 /* Debug Parameters  
  DECLARE  
   @BatchId VARCHAR(MAX)  
   , @ReturnErrorMessage VARCHAR(MAX)  
   , @ErrorLoggedBy      VARCHAR(512) = 'SteveDebug'  
   , @CurrentAction      VARCHAR(4000)  
   , @DT                 VARCHAR(50) = (SELECT SYSDATETIME());  
  
  DECLARE @EsdVersionId_Curr INT = 160  
  DECLARE @EsdVersionId_Prev INT = 152  
  DECLARE @StitchYearWw_Curr INT = 202241  
  DECLARE @Debug BIT = 1  
 --*/  
  DECLARE @Message VARCHAR(MAX)  
  
  DECLARE @StartYearWw_Curr INT, @WwId_Curr INT, @IsReset_Curr BIT, @IsMonthRoll_Curr BIT = 0,   
    @StartYearWw_Prev INT, @StitchYearWw_Prev INT, @IsReset_Prev BIT, @IsMonthRoll_Prev BIT  
  DECLARE @CurrentResetWw  INT  
  
  IF (@StitchYearWw_Curr IS NULL)  
  BEGIN  
   SET @StitchYearWw_Curr = (SELECT YearWw FROM dbo.Intelcalendar WHERE GETDATE() BETWEEN StartDate AND EndDate)  
  END  
  
  --Getting parameters for main logic  
  SELECT @CurrentResetWw = ISNULL(MAX(m.ResetWw), 0) --If no ResetWW defined, use last month's ResetWw  
  FROM dbo.EsdVersions v  
    INNER JOIN dbo.EsdBaseVersions bv ON bv.EsdBaseVersionId = v.EsdBaseVersionId  
    INNER JOIN dbo.PlanningMonths m ON m.PlanningMonthId <= bv.PlanningMonthId  
  WHERE v.EsdVersionId = @EsdVersionId_Curr  
  
  IF @CurrentResetWw = 0 --if @EsdVersionId_Curr is invalid, this would happen  
  BEGIN  
   SET @Message = 'EsdVersionId=' + CAST(@EsdVersionId_Curr AS VARCHAR) + ' has no ResetWw defined! UspLoadEsdSupplyByFgWeek_CorpOp aborted'  
   PRINT @Message  
  
   EXEC dbo.UspAddApplicationLog  
    @LogSource = 'Database'  
    , @LogType = 'Info'  
    , @Category = @ErrorLoggedBy  
    , @SubCategory = @ErrorLoggedBy  
    , @Message = @Message  
    , @Status = 'END'  
    , @Exception = NULL  
    , @BatchId = @BatchId;  
  
   RETURN  
  END  
  
  SET @StartYearWw_Curr = @StitchYearWw_Curr  
  SET @WwId_Curr = (SELECT MAX(WwId) FROM dbo.Intelcalendar WHERE YearWw = @StartYearWw_Curr)  
  
  --Determine @IsReset_Curr  
  IF (@StitchYearWw_Curr > @CurrentResetWw)  
  BEGIN   
   SET @IsReset_Curr = 0  
  END  
  ELSE IF (@StitchYearWw_Curr = @CurrentResetWw)  
  BEGIN  
   SET @IsReset_Curr = 1  
  END  
  ELSE  
  BEGIN  
   SET @Message = 'Parameter @EsdVersionId_Curr and @StitchYearWw_Curr do not match -- StitchWw cannot be before ResetWw, UspLoadEsdSupplyByFgWeek_CorpOp aborted!'  
   PRINT @Message  
  
   EXEC dbo.UspAddApplicationLog  
    @LogSource = 'Database'  
    , @LogType = 'Info'  
    , @Category = @ErrorLoggedBy  
    , @SubCategory = @ErrorLoggedBy  
    , @Message = @Message  
    , @Status = 'END'  
    , @Exception = NULL  
    , @BatchId = @BatchId;  
  
   RETURN  
  END  
  
  --Preserve @StitchYearWw_Prev, @IsReset_Prev, @IsMonthRoll_Prev for updating at the end  
  SELECT @StitchYearWw_Prev = MAX(LastStitchYearWw), @IsReset_Prev = MAX(CAST(IsReset AS INT)), @IsMonthRoll_Prev = MAX(CAST(IsMonthRoll AS INT))  
  FROM dbo.EsdSupplyByFgWeekSnapshot  
  WHERE EsdVersionId = @EsdVersionId_Prev  
   
  --IF @ESDVersion_Prev was NOT used in stitch, follow copy trail to find which copied-from version was last used in the stitch  
  WHILE ( @StitchYearWw_Prev IS NULL)  
  BEGIN  
   SELECT @EsdVersionId_Prev = CopyFromEsdVersionId FROM dbo.EsdVersions WHERE EsdVersionId = @EsdVersionId_Prev  
  
   IF (@EsdVersionId_Prev IS NULL) --None of the version in the copying chain was used in stitch, this is a problem, no need to proceed to stitch  
   BEGIN  
    SET @Message = 'None of the version in the copying chain was used in stitch, UspLoadEsdSupplyByFgWeek_CorpOp aborted!'  
    PRINT @Message  
  
    EXEC dbo.UspAddApplicationLog  
     @LogSource = 'Database'  
     , @LogType = 'ERROR'  
     , @Category = @ErrorLoggedBy  
     , @SubCategory = @ErrorLoggedBy  
     , @Message = @Message  
     , @Status = 'END'  
     , @Exception = NULL  
     , @BatchId = @BatchId;  
  
    RETURN   
   END  
  
   SELECT @StitchYearWw_Prev = MAX(LastStitchYearWw), @IsReset_Prev = MAX(CAST(IsReset AS INT)), @IsMonthRoll_Prev = MAX(CAST(IsMonthRoll AS INT))  
   FROM dbo.EsdSupplyByFgWeekSnapshot  
   WHERE EsdVersionId = @EsdVersionId_Prev  
  END  
    
  --SET Starting WW of the past data to be re-calced  
  SET @StartYearWw_Prev = @StitchYearWw_Prev  
  
  IF (@StitchYearWw_Curr = (SELECT MIN (YearWw) FROM dbo.Intelcalendar WHERE MonthId =   
         (SELECT MonthId FROM dbo.Intelcalendar WHERE YearWw = @StitchYearWw_Curr)) )  
  BEGIN  
   SET @IsMonthRoll_Curr = 1  
  END  
  
  IF (@Debug = 1)    
  BEGIN    
   PRINT '@StitchYearWw_Curr=' + CAST(@StitchYearWw_Curr AS VARCHAR)      
   PRINT '@CurrentResetWw=' + CAST(@CurrentResetWw AS VARCHAR)      
   PRINT '--'    
   PRINT '@EsdVersionId_Curr=' + CAST(@EsdVersionId_Curr AS VARCHAR)    
   PRINT '@StartYearWw_Curr=' + CAST(@StartYearWw_Curr AS VARCHAR)     
   PRINT '@IsReset_Curr=' + CAST(@IsReset_Curr AS VARCHAR)      
   PRINT '@IsMonthRoll_Curr=' + CAST(@IsMonthRoll_Curr AS VARCHAR)      
   PRINT '--'    
   PRINT '@EsdVersionId_Prev=' + CAST(@EsdVersionId_Prev AS VARCHAR)     
   PRINT '@StartYearWw_Prev=' + CAST(@StartYearWw_Prev AS VARCHAR)      
   PRINT '@IsReset_Prev=' + CAST(@IsReset_Prev AS VARCHAR)      
   PRINT '@IsMonthRoll_Prev=' + CAST(@IsMonthRoll_Prev AS VARCHAR)      
  END   
  
  --DON'T RUN Stitch if this is neither a reset week nor a first week of a month  
  IF (@IsReset_Curr = 0 AND @IsMonthRoll_Curr = 0)  
  BEGIN  
   SET @Message = 'Aborted! No stitch is allowed since this is neither a reset week nor a first week of a month!'  
  
   IF (@Debug = 1)  
   BEGIN  
    PRINT '----------------------------------------------------------------------------------------------'  
    PRINT @Message  
    PRINT '----------------------------------------------------------------------------------------------'  
   END  
   ELSE  
   BEGIN     
    EXEC dbo.UspAddApplicationLog  
     @LogSource = 'Database'  
     , @LogType = 'Info'  
     , @Category = @ErrorLoggedBy  
     , @SubCategory = @ErrorLoggedBy  
     , @Message = @Message  
     , @Status = 'END'  
     , @Exception = NULL  
     , @BatchId = @BatchId;  
   END  
  
   RETURN  
  END  
  
  --MAIN LOGIC START  
  -------------------- 1. Declare Temporary table structure and scalar variables --------------------  
  -- Table Structure for Current and Future related data   
  DROP TABLE IF EXISTS #AllKeys_Future  
  CREATE TABLE #AllKeys_Future (ItemName VARCHAR(50), YearWw INT, WwId INT PRIMARY KEY (ItemName, YearWw))  
  DROP TABLE IF EXISTS #AllKeys_Past  
  CREATE TABLE #AllKeys_Past (ItemName VARCHAR(50), YearWw INT, WwId INT PRIMARY KEY (ItemName, YearWw))  
  DROP TABLE IF EXISTS #Qty_Curr  
  CREATE TABLE #Qty_Curr (QtyType INT, ItemName VARCHAR(50), YearWw INT, Qty FLOAT PRIMARY KEY (QtyType, ItemName, YearWw))  
  DROP TABLE IF EXISTS #Qty_Past  
  CREATE TABLE #Qty_Past (QtyType INT, ItemName VARCHAR(50), YearWw INT, Qty FLOAT PRIMARY KEY (QtyType, ItemName, YearWw))  
  
  
  -------------------- 1a. Update the Item List in needed for the respective runs --------------------  
  DECLARE @SourceApplicationId_Fabmps INT = 1  
  DECLARE @SourceApplicationId_Ismps INT = 2  
  DECLARE @SourceApplicationId_Onemps INT = 5  
  DECLARE @ItemClassId_FG INT = 1  
  DROP TABLE IF EXISTS #Items  
  CREATE TABLE #Items (ItemName VARCHAR(50), SolveGroupName VARCHAR(50), PRIMARY KEY (ItemName))  
  
  INSERT #Items  
   SELECT DISTINCT ItemName, SolveGroupName  
   FROM dbo.MpsFgItems  
   WHERE EsdVersionId in (@ESDVersionId_Curr, @ESDVersionId_Prev)  
     AND SourceApplicationName = 'OneMps'  
  
  INSERT #Items  
   SELECT DISTINCT ItemName, SolveGroupName  
   FROM dbo.MpsFgItems i  
   WHERE EsdVersionId in (@ESDVersionId_Curr, @ESDVersionId_Prev)  
     AND SourceApplicationName <> 'OneMps'  
     AND NOT EXISTS (SELECT * FROM #Items WHERE ItemName = i.ItemName)  
  
  DECLARE @EndYearWw_Curr INT = (SELECT MAX(YearWw) FROM dbo.MpsWoiWithoutExcess WHERE EsdVersionId = @EsdVersionId_Curr)  
  --DECLARE @HorizonEndYyyyWw_Prev INT = (SELECT MAX(YearWw) FROM esd.EsdDataWoiWithoutExcess WHERE EsdVersionId = @EsdVersionId_Prev)  
  
  INSERT #AllKeys_Future (ItemName, YearWw, WwId)  
   SELECT DISTINCT ItemName, YearWw, WwId  
   FROM #Items  
     CROSS JOIN (SELECT DISTINCT YearWw, WwId FROM dbo.IntelCalendar WHERE YearWw  BETWEEN @StartYearWw_Curr AND @EndYearWw_Curr) t  
  
  INSERT #AllKeys_Past (ItemName, YearWw, WwId)  
   SELECT DISTINCT ItemName, YearWw, WwId  
   FROM (  
      SELECT ItemName FROM #Items   
      UNION --adding all items with billing but no solver data  
      SELECT DISTINCT ItemName   
      FROM dbo.ActualBillings  
      WHERE YearWw >=  @StartYearWw_Prev AND YearWw < @StartYearWw_Curr  
        AND ISNULL(Quantity, 0) <> 0  
     ) i  
     CROSS JOIN (SELECT DISTINCT YearWw, WwId FROM dbo.IntelCalendar WHERE YearWw >= @StartYearWw_Prev AND YearWw < @StartYearWw_Curr) t  
   
  
  -------------------- 2. Fetch Data FROM previous stitch result up to last week, which are relevant for the current exectuion --------------------  
  -- Sellable Excess Calculation  
  -- Fetch MPS Sellable (Forecast values for prior period) FROM EsdDataSupplyStitch for the Reset/ Roll Qtr Period  
  DECLARE @LastStitchYearWw_EsdVersionId_Prev INT = (SELECT MAX(LastStitchYearWw) FROM dbo.EsdSupplyByFgWeekSnapshot WHERE EsdVersionId = @EsdVersionId_Prev)  
  DROP TABLE IF EXISTS #MPSSellable_Reset_Prev_Period_Forecast;  
  SELECT s.ItemName, @StartYearWw_Curr AS YearWw, Sum([MPSSellableSupply]) AS [MPSSellableSupply]  
  INTO #MPSSellable_Reset_Prev_Period_Forecast  
  FROM dbo.EsdSupplyByFgWeekSnapshot s  
    INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = s.ItemName   
  WHERE EsdVersionId = @EsdVersionId_Prev AND LastStitchYearWw = @LastStitchYearWw_EsdVersionId_Prev AND YearWw >= @StartYearWw_Prev AND YearWw <= @StartYearWw_Curr  
  GROUP BY s.ItemName  
  
  -------------------- 3. Fetch data for Current and Future Weeks FROM the respective DB tables --------------------  
  --Unrestricted BOH  
  IF @IsReset_Curr = 1 --If Current Ww Is ResetWw, use MPS BOH otherwise use Actual BOH  
  BEGIN  
   INSERT INTO #Qty_Curr  
    SELECT 1, b.ItemName, YearWw, SUM(Quantity) AS Quantity -- 1 -BOH  
    FROM dbo.MpsBoh b  
      INNER JOIN #Items i ON i.ItemName = b.ItemName  
    WHERE YearWw = @StartYearWw_Curr  
      AND EsdVersionId = @EsdVersionId_Curr  
    GROUP BY b.ItemName, YearWw  
  END  
  ELSE  
  BEGIN  
   INSERT INTO #Qty_Curr  
    SELECT 1, b.ItemName, YearWw, SUM(Boh) AS Boh  
    FROM dbo.ActualBoh b       
      INNER JOIN #Items i ON i.ItemName = b.ItemName  
    WHERE YearWw = @StartYearWw_Curr  
      AND ( SourceApplicationName = 'AIRSQL'  
         OR (SourceApplicationName = 'OneMps' AND SupplyCategory NOT IN ('AGED', 'LOOSE', 'REWORK', 'Other') )   
      )  
    GROUP BY b.ItemName, YearWw  
  END  
  --select * from #Qty_Curr where YearWw = 2022241 and itemname = '999h22'  
   
  --Total Adj Tgt WOI--   
  INSERT INTO #Qty_Curr  
   SELECT 2, t.ItemName, YearWw, TotTgtWoiWithAdj --2 -'TotTgtWoiWithAdj'  
   FROM dbo.MpsTotTgtWoiWithAdj  t       
     INNER JOIN #Items i ON i.ItemName = t.ItemName  
   WHERE YearWw >= @StartYearWw_Curr AND EsdVersionId = @EsdVersionId_Curr  
  
  --One WOI  
  INSERT INTO #Qty_Curr  
   SELECT 3, ItemName, YearWw, [OneWOI] --3-'OneWoi'  
   FROM dbo.MpsOneWoi AS WOI  
   WHERE WOI.YearWw >= @StartYearWw_Curr  
     AND ItemName IN ( SELECT DISTINCT (ItemName) FROM #Items)  
     AND EsdVersionId = @EsdVersionId_Curr  
   
  --OneWOI BOH--  
  INSERT INTO #Qty_Curr  
   SELECT 4, ItemName, YearWw, SUM(Lag_OneWOI) --4- OneWoiBoh  
   FROM (  
     SELECT *  
       , LAG(OneWOI) OVER (PARTITION BY ItemName ORDER BY YearWw) AS Lag_OneWOI  
     FROM (  
        SELECT t.Itemname, YearWw, OneWOI  
        FROM dbo.MpsOneWoi  t       
          INNER JOIN #Items i ON i.ItemName = t.ItemName   
        WHERE EsdVersionId = @EsdVersionId_Curr   
        UNION ALL  
        SELECT t.ItemName, YearWw, OneWOI  
        FROM dbo.MpsOneWoiPreHorizonWeek  t       
          INNER JOIN #Items i ON i.ItemName = t.ItemName      
        WHERE EsdVersionId = @EsdVersionId_Curr    
       ) AS A  
     ) AS B  
   WHERE YearWw = @StartYearWw_Curr  
   GROUP BY ItemName, YearWw  
  
  --select * from #Qty_Curr where ItemName = '99A33C' AND YearWw = 202026  
  
  --FG Supply Reqt--  
  INSERT INTO #Qty_Curr  
   SELECT  QtyType, t.ItemName, t.YearWw, SUM(FGSupplyReqt) AS FGSupplyReqt  
   FROM (  
      SELECT 5 AS QtyType, t.ItemName, t.YearWw,   
        SUM(ISNULL(Supply, 0)) AS FGSupplyReqt  
      FROM dbo.MpsSupply   t     --??? do we take all suply types?  
        INNER JOIN #Items i ON i.ItemName = t.ItemName   
      WHERE t.YearWw >= @StartYearWw_Curr  
        AND t.EsdVersionId = @EsdVersionId_Curr  
      GROUP BY t.ItemName, t.YearWw  
      UNION ALL  
      SELECT 5, t.ItemName, t.YearWw,   
        SUM(CASE WHEN @IsReset_Curr = 1 AND t.YearWw = @StartYearWw_Curr THEN ISNULL(t.DemandActual, 0) ELSE 0 END) AS FGSupplyReqt  
      FROM dbo.MpsDemandActual   t       
        INNER JOIN #Items i ON i.ItemName = t.ItemName   
      WHERE t.YearWw >= @StartYearWw_Curr  
        AND t.EsdVersionId = @EsdVersionId_Curr  
      GROUP BY t.ItemName, t.YearWw  
     ) AS t  
   GROUP BY QtyType, t.ItemName, t.YearWw  
  
  --WOI Without Excess  
  INSERT INTO #Qty_Curr  
   SELECT 6, t.ItemName, YearWw, WoiWithoutExcess -- 6-'WoiWithoutExcess'  
   FROM dbo.MPSWoiWithoutExcess t  
     INNER JOIN #Items i ON i.ItemName = t.ItemName   
   WHERE EsdVersionId = @EsdVersionId_Curr  
     AND YearWw >= @StartYearWw_Curr  
   
  --Mrb BonusBack  
  INSERT INTO #Qty_Curr  
   SELECT 7, t.ItemName, YearWw, SUM(MrbBonusBack) -- 7-'MrbBonusBack' -- SUM it as MPS may "bonus back" to both VF and specific location  
   FROM dbo.MpsMrbBonusback t  
     INNER JOIN #Items i ON i.ItemName = t.ItemName   
   WHERE YearWw >= @StartYearWw_Curr  
     AND EsdVersionId = @EsdVersionId_Curr  
     AND (SourceApplicationName <> 'OneMPS' OR (SourceApplicationName = 'OneMPS' AND LocationName = 'VF')) --For OneMPS only use VF  
   GROUP BY t.ItemName, YearWw  
  
  --Eoh   
  INSERT INTO #Qty_Curr  
   SELECT 8, t.ItemName, YearWw, SUM(Eoh) Eoh --8-'Eoh' --OneMPS sometimes has Eoh for multiple locations for the same item/week  
   FROM dbo.MpsEoh t  
     INNER JOIN #Items i ON i.ItemName = t.ItemName   
   WHERE YearWw >= @StartYearWw_Curr  
     AND EsdVersionId = @EsdVersionId_Curr  
   GROUP BY t.ItemName, YearWw  
  
  IF (@Debug = 1)  
  BEGIN  
   SELECT CASE QtyType   
      WHEN 1 THEN 'BOH' WHEN 2 THEN 'TotTgtWoiWithAdj' WHEN 3 THEN 'OneWoi' WHEN 4 THEN 'OneWoiBoh'  
      WHEN 5 THEN 'Supply' WHEN 6 THEN 'WoiWithoutExcess' WHEN 7 THEN 'MrbBonusBack' WHEN 8 THEN 'Eoh' ELSE NULL END AS QtyType,  
     COUNT(*) AS [RowCount]  
   FROM #Qty_Curr   
   GROUP BY QtyType   
   ORDER BY 1  
  END  
  
  -------------------- 4. Aggregate data for Current and Future Weeks FROM section 3 and add populate the calculated fields --------------------  
  DROP TABLE IF EXISTS #Calc_Curr;  
  SELECT k.ItemName  
    , k.YearWw  
    , k.WwId  
    , SUM(ISNULL(onewoi.Qty,0)) AS OneWoi  
    , SUM(ISNULL(totalwoi.Qty,0)) AS TotalAdjWoi  
    , SUM(ISNULL(boh.Qty,0)) AS [UnrestrictedBoh]  
    , SUM(ISNULL(WoiWithoutExcess.Qty,0)) AS [WoiWithoutExcess]  
    , SUM(ISNULL(supply.Qty,0)) AS FgSupplyReqt  
    , SUM(ISNULL(mrb.Qty,0)) AS MrbBonusBack  
    , SUM(ISNULL(onewoiboh.Qty,0)) AS OneWoiBoh  
    , SUM(ISNULL(eoh.Qty,0)) AS Eoh  
  INTO #Calc_Curr  
  FROM #AllKeys_Future k  
    LEFT JOIN #Qty_Curr boh ON boh.QtyType = 1 AND boh.ItemName = k.ItemName AND boh.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr totalwoi ON totalwoi.QtyType = 2 AND totalwoi.ItemName = k.ItemName AND totalwoi.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr onewoi ON  onewoi.QtyType = 3 AND onewoi.ItemName = k.ItemName AND onewoi.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr onewoiboh ON onewoiboh.QtyType = 4 AND onewoiboh.ItemName = k.ItemName AND onewoiboh.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr supply ON supply.QtyType = 5 AND supply.ItemName = k.ItemName AND supply.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr WoiWithoutExcess ON WoiWithoutExcess.QtyType = 6 AND WoiWithoutExcess.ItemName = k.ItemName AND WoiWithoutExcess.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr mrb ON mrb.QtyType = 7 AND mrb.ItemName = k.ItemName AND mrb.YearWw = k.YearWw  
    LEFT JOIN #Qty_Curr eoh ON eoh.QtyType = 8 AND eoh.ItemName = k.ItemName AND eoh.YearWw = k.YearWw  
  WHERE NOT (boh.ItemName IS NULL AND totalwoi.ItemName IS NULL AND onewoi.ItemName IS NULL AND onewoiboh.ItemName IS NULL   
      AND supply.ItemName IS NULL AND WoiWithoutExcess.ItemName IS NULL AND mrb.ItemName IS NULL AND eoh.ItemName IS NULL)  
  GROUP BY k.ItemName, k.YearWw, k.WwId  
   
  -- SELECT * FROM #Calc_Curr  
  
  --For current YearWw BohTarget, using this Month's POR EsdVersion, Or PrePOR EsdVersion Or the last EsdVersion excluding this EsdVersion whichever is found first in that order  
  --Instead of calculating by ISNULL(TotalAdjWoi,0) * ISNULL([OneWoiBoh],0)  
  DECLARE @PlanningMonth INT = (SELECT PlanningMonth FROM dbo.v_EsdVersions WHERE EsdVersionId = @EsdVersionId_Curr)  
  DECLARE @EsdVersionId_CopyBohTargetFrom INT = ( SELECT TOP 1 EsdVersionId FROM dbo.v_EsdVersions WHERE PlanningMonth = @PlanningMonth and EsdVersionId <> @EsdVersionId_Curr ORDER BY IsPOR DESC, IsPrePOR DESC, EsdVersionId DESC)  
  DECLARE @LastStitchYearWw_EsdVersionId_CopyBohTargetFrom INT = (SELECT MAX(LastStitchYearWw) FROM dbo.EsdSupplyByFgWeekSnapshot WHERE EsdVersionId = @EsdVersionId_CopyBohTargetFrom)  
    
  DROP TABLE IF EXISTS #BohTarget_CurrentMonthPOR  
  SELECT ItemName, YearWw, BohTarget   
  INTO #BohTarget_CurrentMonthPOR  
  FROM dbo.EsdSupplyByFgWeekSnapshot   
  WHERE EsdVersionId = @EsdVersionId_CopyBohTargetFrom AND LastStitchYearWw = @LastStitchYearWw_EsdVersionId_CopyBohTargetFrom AND YearWw = @StartYearWw_Curr  
  
  -- Calculate [BohTarget], [SellableEOH]  
  DROP TABLE IF EXISTS #Calc_Curr1  
  SELECT c.*  
    --, CASE WHEN c.YearWw = @StartYearWw_Curr THEN ISNULL(TotalAdjWoi,0) * ISNULL([OneWoiBoh],0) ELSE 0 END AS [BohTarget]  
    , CASE WHEN c.YearWw = @StartYearWw_Curr THEN bt.BohTarget ELSE 0 END AS [BohTarget]  
    , ISNULL(OneWoi,0) * ISNULL([WoiWithoutExcess],0) AS [SellableEOH]  
  INTO #Calc_Curr1  
  FROM #Calc_Curr c  
    LEFT JOIN #BohTarget_CurrentMonthPOR bt ON bt.ItemName = c.ItemName AND bt.YearWw = c.YearWw   
  
  UPDATE #Calc_Curr1 SET [BohTarget] = 0 WHERE [BohTarget] < 0  
  
  --SELECT * FROM #Calc_Curr1  
  
  /*  
  --Hard-coding per Rajbir request, just for 2 iCDG solver groups, due to some specific solver reason: SET BohExcess AND EohExcess to 0  
  --Hi Steve,  
  --Could you assume all FG excess is sellable for XG756 and XG66 in the code? The solver is not set up correctly, so planning and CSBP assume all FG excess is sellable  
  --Thanks,  
  --Rajbir  
  */  
  DROP TABLE IF EXISTS #iCDGItems  
  SELECT DISTINCT ItemName  
  INTO #iCDGItems  
  FROM #Items   
  WHERE SolveGroupName in ('iCDG_XG756', 'iCDG_XG766')   
    
  -- Calculate [BohExcess]  
  DROP TABLE IF EXISTS #Calc_Curr2  
  SELECT d.*  
    , CASE WHEN i.ItemName IS NOT NULL THEN 0  
        ELSE (  
        CASE   
         WHEN (CAST(YearWw AS INT) > @StartYearWw_Curr) THEN 0  
         WHEN (CAST(YearWw AS INT) = @StartYearWw_Curr) THEN iif(ISNULL([UnrestrictedBoh],0) <= ISNULL([BohTarget],0), 0,   
                         ISNULL([UnrestrictedBoh],0) - ISNULL([BohTarget],0))  
         ELSE 0  
        END   
       )  
     END AS [BohExcess]    
  INTO #Calc_Curr2  
  FROM #Calc_Curr1 d  
    LEFT JOIN #iCDGItems i On i.ItemName = d.ItemName  
  -- SELECT * FROM #Calc_Curr2;  
  
  -- Calculate [SellableBOH]  
  DROP TABLE IF EXISTS #Calc_Curr3  
  SELECT *  
    , CASE    
     WHEN (CAST(YearWw AS INT) = @StartYearWw_Curr) THEN (ISNULL([UnrestrictedBoh], 0) - ISNULL([BohExcess], 0))  
     ELSE 0  
     END AS [SellableBOH]  
  INTO #Calc_Curr3  
  FROM #Calc_Curr2  
  -- SELECT * FROM #Calc_Curr3 where ItemName = '999H22' and yearww = 202022;  
  
  -- Calculate EohExcess, [Lag_EohExcess]  
  --For MMs that have Boh, but no Solver Demand, no Solver Eoh, and no Solver Transportation Schedule(supply), set EohExcess = BohExcess   
  --Find all Items HAVING Boh but no demand in the entire MPS version horizon  
  DROP TABLE IF EXISTS #ItemsWithBohButNoSolverData  
  
  SELECT  DISTINCT ItemName  
  INTO #ItemsWithBohButNoSolverData  
  FROM dbo.MpsBoh b  
  WHERE b.EsdVersionId = @EsdVersionId_Curr AND b.YearWw = @StartYearWw_Curr --and SourceApplicationName = 'FabMPS'  
    AND Quantity <> 0  
    AND NOT EXISTS (  
     SELECT DISTINCT EsdVersionId, itemname  
     FROM dbo.MpsDemand  
     WHERE EsdVersionId = b.EsdVersionId AND ItemName = b.ItemName  
     GROUP BY EsdVersionId, itemname  
     HAVING SUM(Demand) <> 0  
    )  
    AND NOT EXISTS (  
     SELECT DISTINCT EsdVersionId, itemname  
     FROM dbo.MpsEoh  
     WHERE EsdVersionId = b.EsdVersionId AND ItemName = b.ItemName  
     GROUP BY EsdVersionId, itemname  
     HAVING SUM(Eoh) <> 0  
    )  
    AND NOT EXISTS (  
     SELECT DISTINCT EsdVersionId, itemname  
     FROM dbo.MpsSupply  
     WHERE EsdVersionId = b.EsdVersionId AND ItemName = b.ItemName  
     GROUP BY EsdVersionId, itemname  
     HAVING SUM(Supply) <> 0  
    )  
    AND NOT EXISTS (  
     SELECT DISTINCT EsdVersionId, itemname  
     FROM dbo.MpsFinalSolverDemand  
     WHERE EsdVersionId = b.EsdVersionId AND ItemName = b.ItemName  
     GROUP BY EsdVersionId, itemname  
     HAVING SUM(Quantity) <> 0  
    )  
  
  DROP TABLE IF EXISTS #Calc_Curr4  
  SELECT d.*  
    , CASE  WHEN i.ItemName IS NOT NULL THEN 0   
      WHEN i2.ItemName IS NOT NULL AND YearWw = @StartYearWw_Curr THEN [BohExcess]   
      ELSE iif(ISNULL(Eoh,0) <= ISNULL([SellableEOH],0), 0, ISNULL(Eoh,0) - ISNULL([SellableEOH],0)) END AS EohExcess  
        
    , CASE  WHEN i.ItemName IS NOT NULL THEN 0   
      WHEN i2.ItemName IS NOT NULL AND Wwid = @WwId_Curr + 1 THEN [BohExcess]  
      ELSE Lag(iif(ISNULL(Eoh,0) <= ISNULL([SellableEOH],0), 0, ISNULL(Eoh,0) - ISNULL([SellableEOH],0))) OVER (PARTITION BY d.ItemName ORDER BY YearWw ) END AS [Lag_EohExcess]  
  INTO #Calc_Curr4  
  FROM #Calc_Curr3 d  
    LEFT JOIN #iCDGItems i On i.ItemName = d.ItemName  
    LEFT JOIN #ItemsWithBohButNoSolverData i2 ON i2.ItemName = d.ItemName  
 -- SELECT * FROM #Calc_Curr4;  
  
  -- Calculate DiscreteEohExcess  
  DROP TABLE IF EXISTS #Calc_Curr5;  
  SELECT *  
    , CASE WHEN (CAST(YearWw AS INT) = @StartYearWw_Curr) THEN (ISNULL([EohExcess],0) - ISNULL([BohExcess],0))  
      ELSE             (ISNULL([EohExcess],0) - ISNULL([Lag_EohExcess],0))  
      END AS DiscreteEohExcess  
  INTO #Calc_Curr5  
  FROM #Calc_Curr4;  
  -- SELECT * FROM #Calc_Curr5;  
   
  -- Calculate [MPSSellableSupply] -- Current Horizon  
  DROP TABLE IF EXISTS #Calc_Curr6;  
  SELECT *  
    , ISNULL([FgSupplyReqt],0) - ISNULL(DiscreteEohExcess,0) + ISNULL([MrbBonusBack],0)  AS [MPSSellableSupply]  
  INTO #Calc_Curr6  
  FROM #Calc_Curr5;  
  -- SELECT * FROM #Calc_Curr6;  
  
  -- New Sellable Eoh Calculation for current and future Ww  
  DROP TABLE IF exists #FinalSoverDemands   
  
  SELECT ItemName, YearWw, SUM(Quantity) AS DemandToGo  
  INTO #FinalSoverDemands  
  FROM dbo.MpsFinalSolverDemand  
  WHERE EsdVersionId = @EsdVersionId_Curr  
  GROUP BY ItemName, YearWw  
  
  DROP TABLE IF exists #NewEohCum1_Curr   
  SELECT a.ItemName, a.YearWw  
    , CASE WHEN a.YearWw = @StartYearWw_Curr THEN (ISNULL([SellableBOH],0) + ISNULL([MPSSellableSupply],0) - ISNULL(DemandToGo,0))  
      ELSE (ISNULL([MPSSellableSupply],0) - ISNULL(d.DemandToGo,0))  
      END AS NewEoh  
  INTO #NewEohCum1_Curr  
  FROM #Calc_Curr6 AS a  
    LEFT JOIN #FinalSoverDemands d ON d.ItemName = a.ItemName AND d.YearWw = a.YearWw  
  
  ALTER TABLE #NewEohCum1_Curr ADD PRIMARY KEY (ItemName, YearWw);  
   
  DROP TABLE IF EXISTS #NewEohCum2_Curr  
  SELECT a.ItemName, a.YearWw, SUM(b.NewEoh) AS NewEoh  
  INTO #NewEohCum2_Curr  
  FROM #NewEohCum1_Curr a   
    LEFT JOIN #NewEohCum1_Curr b ON b.ItemName = a.ItemName AND b.YearWw <= a.YearWw  
  GROUP BY a.ItemName, a.YearWw  
     
  ALTER TABLE #NewEohCum2_Curr ADD PRIMARY KEY (ItemName, YearWw);  
  -- SELECT * FROM #NewEohCum1_Curr;  
  
  DROP TABLE IF EXISTS #Calc_Curr7;  
  SELECT a.*  
    , n.NewEoh  
  INTO #Calc_Curr7  
  FROM #Calc_Curr6 a  
    LEFT JOIN #NewEohCum2_Curr n ON n.ItemName = a.ItemName AND n.YearWw = a.YearWw  
  -- SELECT * FROM #Calc_Curr7;  
  
     
  -------------------- 5. Store specific data FROM section 3 and 4 which will be used later on for Actual calcautions --------------------  
  -- Save current ww [SellableBOH] for later use to calc ExcessAdjust for the week before reset  
  DROP TABLE IF EXISTS #Sellable_BOH_Curr  
  
  SELECT [SellableBOH], ItemName, WwId  
  INTO #Sellable_BOH_Curr  
  FROM #Calc_Curr7  
  WHERE YearWw = @StartYearWw_Curr   
    
  INSERT #Sellable_BOH_Curr --Add placeholder rows for box MMs   
   SELECT DISTINCT 0, ItemName, @WwId_Curr  
   FROM #AllKeys_Past a  
   WHERE NOT EXISTS (SELECT * FROM #Sellable_BOH_Curr WHERE ItemName = a.ItemName)  
  
  --select distinct ItemName, Wwid from #Sellable_BOH_Curr where Itemname = '99A0V8'  
  
  -------------------- 6. Fetch data for Past Weeks FROM the respective DB tables --------------------  
  
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  
  ------------------------------------------------------------------------------Past Section ---------------------------------------------------------------------------------------------------------------  
  ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------  
  --BOH  
  --If last stitch Ww was a Reset Ww, use MPS BOH otherwise use Actual BOH  
  IF EXISTS ( SELECT * FROM dbo.PlanningMonths WHERE ResetWw = @StartYearWw_Prev)   
  BEGIN  
   INSERT INTO #Qty_Past  
    SELECT 1, b.ItemName, YearWw, SUM(Quantity) AS Quantity -- 1 -BOH  
    FROM dbo.MpsBoh b  
      INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = b.ItemName   
    WHERE YearWw = @StartYearWw_Prev  
      AND EsdVersionId = @EsdVersionId_Prev  
    GROUP BY b.ItemName, YearWw  
  END  
  ELSE  
  BEGIN  
   INSERT INTO #Qty_Past  
    SELECT 1, b.ItemName, YearWw, SUM(Boh) AS Boh  
    FROM dbo.ActualBoh b       
      INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = b.ItemName   
    WHERE YearWw = @StartYearWw_Prev  
      AND ( SourceApplicationName = 'AIRSQL'     
         OR (SourceApplicationName = 'OneMps' AND SupplyCategory NOT IN ('AGED', 'LOOSE', 'REWORK', 'Other') )   
      )  
    GROUP BY b.ItemName, YearWw  
  END  
 --select * from #Qty_Past where QtyType = 1 and ItemName = '999H22'  
  
  
  --Total Adj Tgt WOI  
  INSERT #Qty_Past  
   SELECT 2, t.ItemName, YearWw, TotTgtWoiWithAdj  
   FROM dbo.MpsTotTgtWoiWithAdj t       
     INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName   
   WHERE YearWw >= @StartYearWw_Prev  
     AND YearWw < @StartYearWw_Curr  
     AND EsdVersionId = @ESDVersionId_Prev   
  
  --One WOI  
  INSERT #Qty_Past  
   SELECT 3, t.ItemName, YearWw, [OneWOI]  
   FROM dbo.MpsOneWoi t  
     INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName   
   WHERE YearWw >= @StartYearWw_Prev  
     AND YearWw < @StartYearWw_Curr  
     AND EsdVersionId = @EsdVersionId_Prev  
  
  --OneWOI BOH--  
  INSERT #Qty_Past  
   SELECT 4, ItemName, YearWw, SUM(Lag_OneWOI) --4- OneWoiBoh  
   FROM (  
     SELECT *  
       , LAG(OneWOI) OVER (PARTITION BY ItemName ORDER BY YearWw) AS Lag_OneWOI  
     FROM (  
        SELECT t.Itemname, YearWw, OneWOI  
        FROM dbo.MpsOneWoi  t       
          INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName    
        WHERE EsdVersionId = @EsdVersionId_Prev   
        UNION ALL  
        SELECT t.ItemName, YearWw, OneWOI  
        FROM dbo.MpsOneWoiPreHorizonWeek  t       
          INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName       
        WHERE EsdVersionId = @EsdVersionId_Prev    
       ) AS A  
     ) AS B  
   WHERE YearWw = @StartYearWw_Prev  
   GROUP BY ItemName, YearWw  
  
  --TestOutActual  
  INSERT #Qty_Past  
   SELECT 9, t.ItemName, YearWw, SUM(Quantity) AS TestOutActual  
   FROM dbo.ActualSupply t --??? QuantityType='IFG Test Out Actual'?  
     INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName   
   WHERE YearWw >= @StartYearWw_Prev  
     AND YearWw < @StartYearWw_Curr  
   GROUP BY t.ItemName, YearWw  
   
  --Billings + TMG Shipment  
  INSERT #Qty_Past  
   SELECT 10, t.ItemName, YearWw, SUM(Quantity) AS Billings  
   FROM dbo.ActualBillings t       
     INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName   
   WHERE YearWw >= @StartYearWw_Prev  
     AND YearWw < @StartYearWw_Curr  
     AND ISNULL(t.Quantity, 0) <> 0  
   GROUP BY t.ItemName, YearWw  
  
  -- Fetch FG movement data  
  DROP TABLE IF EXISTS #Movements  
  CREATE TABLE #Movements (ItemName VARCHAR(50), YearWw INT, Scrapped FLOAT,RMA FLOAT,Rework FLOAT,Blockstock FLOAT PRIMARY KEY (ItemName, YearWw))  
  INSERT #Movements  
   SELECT ItemName, YearWw, SUM(Scrapped) Scrapped, SUM(RMA) RMA, SUM(Rework) Rework, SUM(Blockstock) Blockstock  
   FROM (  
      SELECT t.ItemName  
        , YearWw  
        , CASE WHEN (MovementType = 'scrap_qty') THEN Quantity END AS Scrapped  
        , CASE WHEN (MovementType = 'rma_qty') THEN Quantity END AS RMA  
        , CASE WHEN (MovementType = 'rework_qty') THEN Quantity END AS Rework  
        , CASE WHEN (MovementType = 'blockstock_qty') THEN Quantity END AS Blockstock  
      FROM dbo.ActualFgMovements  t    
        INNER JOIN ( SELECT DISTINCT ItemName FROM #AllKeys_Past) i ON i.ItemName = t.ItemName   
      WHERE YearWw >= @StartYearWw_Prev  
        AND YearWw < @StartYearWw_Curr  
     ) t  
   GROUP BY ItemName, YearWw  
   
  --select * from #Movements  
  
  IF (@Debug = 1)  
  BEGIN  
   SELECT CASE QtyType   
      WHEN 1 THEN 'Past-BOH'   
      WHEN 2 THEN 'Past-TotTgtWoiWithAdj'   
      WHEN 3 THEN 'Past-OneWoi'   
      WHEN 4 THEN 'Past-OneWoiBoh'  
      WHEN 9 THEN 'Past-TestOutActual'   
      WHEN 10 THEN 'Past-Billings' END AS QtyType,  
     COUNT(*) AS [RowCount]  
   FROM #Qty_Past   
   GROUP BY QtyType ORDER BY 1  
    
   SELECT 'Past-Movements', COUNT(*) AS [RowCount] FROM #Movements  
  END  
  
  
  -------------------- 7. Aggregate data for Past Weeks FROM section 6 and add populate the calculated fields  --------------------  
   
  DROP TABLE IF EXISTS #Calc_Past;  
  SELECT k.ItemName  
    , k.YearWw  
    , k.WwId  
    , SUM(ISNULL(onewoi.Qty,0)) AS OneWoi  
    , SUM(ISNULL(totaladjwoi.Qty,0)) AS TotalAdjWoi  
    , SUM(ISNULL(boh.Qty,0)) AS [UnrestrictedBoh]  
    , SUM(ISNULL(testout.Qty,0)) AS TestOutActual  
    , SUM(ISNULL(billing.Qty,0)) AS Billings  
    , SUM(ISNULL(onewoiboh.Qty,0)) AS OneWoiBoh  
    , SUM(ISNULL(m.Scrapped,0)) AS Scrapped  
    , SUM(ISNULL(m.RMA,0)) AS RMA  
    , SUM(ISNULL(m.Rework,0)) AS Rework  
    , SUM(ISNULL(m.Blockstock,0)) AS Blockstock  
  INTO #Calc_Past  
  FROM #AllKeys_Past k  
    LEFT JOIN #Qty_Past boh ON boh.QtyType = 1 AND boh.ItemName = k.ItemName AND boh.YearWw = k.YearWw  
    LEFT JOIN #Qty_Past totaladjwoi ON totaladjwoi.QtyType = 2 AND totaladjwoi.ItemName = k.ItemName AND totaladjwoi.YearWw = k.YearWw  
    LEFT JOIN #Qty_Past onewoi ON onewoi.QtyType = 3 AND onewoi.ItemName = k.ItemName AND onewoi.YearWw = k.YearWw  
    LEFT JOIN #Qty_Past onewoiboh ON onewoiboh.QtyType = 4 AND onewoiboh.ItemName = k.ItemName AND onewoiboh.YearWw = k.YearWw  
    LEFT JOIN #Qty_Past testout ON testout.QtyType = 9 AND testout.ItemName = k.ItemName AND testout.YearWw = k.YearWw  
    LEFT JOIN #Qty_Past billing ON billing.QtyType = 10 AND billing.ItemName = k.ItemName AND billing.YearWw = k.YearWw  
    LEFT JOIN #Movements m ON m.ItemName = k.ItemName AND m.YearWw = k.YearWw  
  GROUP BY k.ItemName, k.YearWw, k.WwId  
  -- SELECT * FROM #Calc_Past;  
  
  ALTER TABLE #Calc_Past ADD PRIMARY KEY (ItemName, YearWw);  
      
  -- BohTarget Calculation   
  DROP TABLE IF EXISTS #Calc_Past1  
  SELECT a.*  
    , CASE  WHEN YearWw = @StartYearWw_Prev THEN ISNULL([OneWoiBoh],0) * ISNULL(TotalAdjWoi,0)  
      ELSE Lag(ISNULL(OneWoi,0)) OVER ( PARTITION BY a.ItemName ORDER BY YearWw) * ISNULL(TotalAdjWoi,0)  
        --Lag(OneWoi) OVER ( PARTITION BY a.ItemName ORDER BY YearWw)  
        --* Lag(TotalAdjWoi) OVER (PARTITION BY a.ItemName ORDER BY YearWw) -- Original  
      END AS [BohTarget]  
  INTO #Calc_Past1  
  FROM #Calc_past a  
  ORDER BY ItemName, YearWw  
  
  UPDATE #Calc_Past1 SET [BohTarget] = 0 WHERE [BohTarget] < 0 --To make sure there is not BOH in the past weeks  
  -- SELECT * FROM #Calc_Past1;  
  
  
  -- Eoh Calculation   
  DROP TABLE IF exists #EohCum1_Past  
  SELECT a.ItemName, a.YearWw  
    , CASE  WHEN a.YearWw = @StartYearWw_Prev  
      THEN ISNULL(a.[UnrestrictedBoh],0) + ISNULL(a.[TestOutActual],0) - ISNULL(a.[Billings],0)   
        + ISNULL(a.Scrapped,0) + ISNULL(a.RMA,0) + ISNULL(a.Rework,0) + ISNULL(a.Blockstock,0)   
      ELSE ISNULL(a.[TestOutActual],0)  - ISNULL(a.[Billings] ,0)   
        + ISNULL(a.Scrapped,0) + ISNULL(a.RMA,0) + ISNULL(a.Rework,0) + ISNULL(a.Blockstock,0)     
      END AS Eoh  
  INTO #EohCum1_Past  
  FROM #Calc_Past1 a   
  
  ALTER TABLE #EohCum1_Past ADD PRIMARY KEY (ItemName, YearWw);  
   
  DROP TABLE IF EXISTS #EohCum2_Past  
  SELECT a.ItemName, a.YearWw, SUM(b.Eoh) AS Eoh  
  INTO #EohCum2_Past  
  FROM #EohCum1_Past a   
    LEFT JOIN #EohCum1_Past b ON b.ItemName = a.ItemName AND b.YearWw <= a.YearWw  
  GROUP BY a.ItemName, a.YearWw  
     
  ALTER TABLE #EohCum2_Past ADD PRIMARY KEY (ItemName, YearWw);  
  -- SELECT * FROM #EohCum2_Past;  
  
  DROP TABLE IF EXISTS #Calc_Past_Eoh  
  SELECT a.* , e.Eoh AS [Eoh]  
  INTO #Calc_Past_Eoh  
  FROM #Calc_Past1 a  
    LEFT JOIN #EohCum2_Past e ON e.ItemName = a.ItemName AND e.YearWw = a.YearWw;  
  --SELECT * FROM #Calc_Past_Eoh  
   
  -- Eoh Related Calculation   
  DROP TABLE IF EXISTS #Calc_Past2  
  SELECT e.*  
    , CASE WHEN i.ItemName IS NOT NULL THEN 0  
        ELSE (  
        CASE   
         WHEN (YearWw = @StartYearWw_Prev)  
          THEN (iif((ISNULL(e.UnrestrictedBoh,0) - ISNULL(e.[BohTarget],0)) < 0, 0, ISNULL(e.UnrestrictedBoh,0) - ISNULL(e.[BohTarget],0)))  
         ELSE 0  
         END  
       )  
      END AS [BohExcess]  
    , CASE WHEN i.ItemName IS NOT NULL THEN ISNULL(e.UnrestrictedBoh,0)  
        ELSE ISNULL(e.UnrestrictedBoh,0) - (iif((ISNULL(e.UnrestrictedBoh,0) - ISNULL(e.[BohTarget],0)) < 0, 0, ISNULL(e.UnrestrictedBoh,0) - ISNULL(e.[BohTarget],0)))   
        END AS [SellableBOH]  
    , ISNULL(e.TotalAdjWoi,0) * ISNULL(e.OneWOI,0) AS [Eoh Target]  
    , CASE WHEN i.ItemName IS NOT NULL THEN 0  
        ELSE IIF((ISNULL(e.Eoh,0) - (ISNULL(e.TotalAdjWoi,0) * ISNULL(e.OneWOI,0))) < 0, 0, (ISNULL(e.Eoh,0) - (ISNULL(e.TotalAdjWoi,0) * ISNULL(e.OneWOI,0))))   
        END AS [EohExcess]  
  INTO #Calc_Past2  
  FROM #Calc_Past_Eoh e   
    LEFT JOIN #iCDGItems i On i.ItemName = e.ItemName  
  
  --select * from #Calc_Past_Eoh where itemname = '999h22' and yearww = 202022  
  
  -- [DiscreteEohExcess], [SellableSupply]  
  DROP TABLE IF EXISTS #Calc_Past3;  
  SELECT e.*  
    , CASE WHEN (YearWw = @StartYearWw_Prev) THEN (ISNULL([EohExcess],0) - ISNULL([BohExcess],0))  
      ELSE (ISNULL([EohExcess],0) - Lag(ISNULL([EohExcess],0)) OVER (PARTITION BY e.ItemName ORDER BY YearWw))  
      END AS [DiscreteEohExcess]  
    , ISNULL(e.TestOutActual,0) + ISNULL(e.Scrapped,0) + ISNULL(e.RMA,0) + ISNULL(e.Rework,0) + ISNULL(e.Blockstock,0)   
     - CASE WHEN (YearWw = @StartYearWw_Prev) THEN (ISNULL([EohExcess],0) - ISNULL([BohExcess],0))  
       ELSE (ISNULL([EohExcess],0) - Lag(ISNULL([EohExcess],0)) OVER (PARTITION BY e.ItemName ORDER BY YearWw))  
       END AS [SellableSupply]  
  INTO #Calc_Past3  
  FROM #Calc_Past2 AS e;  
  --SELECT * FROM #Calc_Past2  
  
  
  -- Cal Sellable Eoh Calculation   
  DROP TABLE IF exists #SellableEohCum1_Past  
  SELECT a.ItemName, a.YearWw  
    , CASE  WHEN YearWw = @StartYearWw_Prev THEN (ISNULL([SellableBOH],0) + ISNULL([SellableSupply],0) - ISNULL([Billings],0))  
      ELSE (ISNULL([SellableSupply],0) - ISNULL([Billings],0))  
      END AS Calc_Sellable_EOH  
  INTO #SellableEohCum1_Past  
  FROM #Calc_Past3 AS a  
  
  ALTER TABLE #SellableEohCum1_Past ADD PRIMARY KEY (ItemName, YearWw);  
   
  DROP TABLE IF EXISTS #SellableEohCum2_Past  
  SELECT a.ItemName, a.YearWw, SUM(b.Calc_Sellable_EOH) AS Calc_Sellable_EOH  
  INTO #SellableEohCum2_Past  
  FROM #SellableEohCum1_Past a   
    LEFT JOIN #SellableEohCum1_Past b ON b.ItemName = a.ItemName AND b.YearWw <= a.YearWw  
  GROUP BY a.ItemName, a.YearWw  
     
  ALTER TABLE #SellableEohCum2_Past ADD PRIMARY KEY (ItemName, YearWw);  
  -- SELECT * FROM #SellableEohCum2_Past;  
  
  DROP TABLE IF EXISTS #Calc_Past4  
   SELECT a.*  
     , e.Calc_Sellable_EOH AS Calc_Sellable_EOH  
   INTO #Calc_Past4  
   FROM #Calc_Past3 a  
     LEFT JOIN #SellableEohCum2_Past AS e ON e.ItemName = a.ItemName AND e.YearWw = a.YearWw;  
  --SELECT * FROM #Calc_Past4  
  
  DROP TABLE IF EXISTS #PastExcessAdjust  
  SELECT ItemName, YearWw, ExcessAdjust  
  INTO #PastExcessAdjust  
  FROM dbo.EsdSupplyByFgWeek s  
  WHERE YearWw >= @StartYearWw_Prev AND YearWw <@StartYearWw_Curr  
  
  -- [ExcessAdjust]  
  DROP TABLE IF EXISTS #Calc_Past5  
  SELECT a.*  
    , CASE  WHEN a.WwId = (boh.WwId - 1) --Calc ExcessAdjustment for the last week  
       THEN (ISNULL(boh.[SellableBOH],0) - ISNULL(a.Calc_Sellable_EOH,0))   
      ELSE 0.00  
      END AS [ExcessAdjust]  
  INTO #Calc_Past5  
  FROM #Calc_Past4 a --past weeks data  
    INNER JOIN #Sellable_BOH_Curr boh --this has [SellableBOH] for this week only  
     ON a.ItemName = boh.ItemName   
  
  --select * from #Sellable_BOH_Curr where ItemName = '929138'   
  --SELECT * FROM #Calc_Past5 where ItemName = '929138'   
   
  --  MPSSellableSupply Calculation --Past Horizon  
  DROP TABLE IF EXISTS #Calc_Past6;  
  SELECT a.*  
    , ISNULL(a.[SellableSupply],0) + ISNULL(a.[ExcessAdjust],0) AS [MPSSellableSupply]  
  INTO #Calc_Past6  
  FROM #Calc_Past5 AS a  
  
  -- SELECT * FROM #Calc_Past6;  
   
  -- New Sellable Eoh Calculation   
  DROP TABLE IF exists #NewEohCum1_Past  
  SELECT a.ItemName, a.YearWw  
    , CASE WHEN YearWw = @StartYearWw_Prev THEN (ISNULL([SellableBOH],0) + ISNULL([MPSSellableSupply],0) - ISNULL([Billings],0))  
      ELSE (ISNULL([MPSSellableSupply],0) - ISNULL([Billings],0))  
      END AS NewEoh  
  INTO #NewEohCum1_Past  
  FROM #Calc_Past6 AS a  
  
  ALTER TABLE #NewEohCum1_Past ADD PRIMARY KEY (ItemName, YearWw);  
   
  DROP TABLE IF EXISTS #NewEohCum2_Past  
  SELECT a.ItemName, a.YearWw, SUM(b.NewEoh) AS NewEoh  
  INTO #NewEohCum2_Past  
  FROM #NewEohCum1_Past a  
    LEFT JOIN #NewEohCum1_Past b ON b.ItemName = a.ItemName AND b.YearWw <= a.YearWw  
  GROUP BY a.ItemName, a.YearWw  
     
  ALTER TABLE #NewEohCum2_Past ADD PRIMARY KEY (ItemName, YearWw);  
  -- SELECT * FROM #NewEohCum1_Past;  
  
  DROP TABLE IF EXISTS #Calc_Past7  
  SELECT a.*  
    , e.NewEoh  
    , @EsdVersionId_Prev AS [EsdVersionId]  
  INTO #Calc_Past7  
  FROM #Calc_Past6 a  
    LEFT JOIN #NewEohCum2_Past AS e ON e.ItemName = a.ItemName AND e.YearWw = a.YearWw;  
  
  -- Supply Excess Calculations  
  DROP TABLE IF EXISTS #MPSSellable_Reset_Prev_Period_Actual;  
  SELECT DU.ItemName  
    , @StartYearWw_Curr AS YearWw  
    , Sum([MPSSellableSupply]) AS [MPSSellableSupply]  
  INTO #MPSSellable_Reset_Prev_Period_Actual  
  FROM #Calc_Past7 AS DU  
  GROUP BY DU.ItemName;  
  
  
  -------------------- 8. Supply Delta Calculation  --------------------  
  DROP TABLE IF EXISTS #Calc_Curr8;  
  SELECT DU.*  
    , CASE WHEN ( DU.YearWw = @StartYearWw_Curr AND @IsMonthRoll_Curr = 1 AND @IsReset_Curr = 0)  
      THEN (ISNULL(MPS_Forecast.[MPSSellableSupply], 0) - (ISNULL(MPS_Actual.[MPSSellableSupply], 0) + ISNULL(t.MPSSellableSupply,0)) )  
      ELSE 0  
      END AS [SupplyDelta]  
  INTO #Calc_Curr8  
  FROM #Calc_Curr7 AS DU  
    LEFT JOIN #MPSSellable_Reset_Prev_Period_Forecast AS MPS_Forecast   
     ON MPS_Forecast.ItemName = DU.ItemName AND MPS_Forecast.YearWw = DU.YearWw  
    LEFT JOIN #MPSSellable_Reset_Prev_Period_Actual AS MPS_Actual   
     ON MPS_Actual.ItemName = DU.ItemName AND MPS_Actual.YearWw = DU.YearWw  
    LEFT JOIN (SELECT * FROM #Calc_Curr7 WHERE YearWw = @StartYearWw_Curr) t  
     ON t.ItemName = DU.ItemName AND t.YearWw = DU.YearWw  
  
  --Calc SupplyDelta for Non-MPS MM - for @StartYearWw_Curr week only  
  DROP TABLE IF EXISTS #NonMPSSupplyDelta  
  
  SELECT i.ItemName, @StartYearWw_Curr AS YearWw  
    , SUM(ISNULL(MPS_Forecast.[MPSSellableSupply], 0)) - SUM((ISNULL(MPS_Actual.[MPSSellableSupply], 0))) AS [SupplyDelta]  
  INTO #NonMPSSupplyDelta  
  FROM (SELECT DISTINCT ItemName FROM #AllKeys_Past WHERE ItemName NOT IN (SELECT ItemName FROM #Items)) i  
    LEFT JOIN #MPSSellable_Reset_Prev_Period_Forecast AS MPS_Forecast   
     ON MPS_Forecast.ItemName = i.ItemName   
    LEFT JOIN #MPSSellable_Reset_Prev_Period_Actual AS MPS_Actual   
     ON MPS_Actual.ItemName = i.ItemName   
  GROUP BY i.ItemName  
  HAVING SUM(ISNULL(MPS_Forecast.[MPSSellableSupply], 0)) - SUM((ISNULL(MPS_Actual.[MPSSellableSupply], 0))) <> 0  
  
  --select * from #NonMPSSupplyDelta  
  
  --select * from #MPSSellable_Reset_Prev_Period_Forecast where itemname = '999LZD'-- in (select distinct itemname from #AllKeys_Past where itemname not in ( select ItemName from #Items))  
  ----except  
  --select * from #MPSSellable_Reset_Prev_Period_Actual where itemname ='999LZD' --in (select distinct itemname from #AllKeys_Past where itemname not in ( select ItemName from #Items))  
  --select * from #Calc_Curr7 where  YearWw = 202114 and ItemName ='999LZD'-- in (select distinct itemname from #AllKeys_Past where itemname not in ( select ItemName from #Items))  
  --select * from #Calc_Curr8 where  YearWw = 202114 and ItemName ='999LZD'-- in (select distinct itemname from #AllKeys_Past where itemname not in ( select ItemName from #Items))  
  ----select * from #AllKeys_Past where itemname not in ( select ItemName from #Items where itemname = '985857')  
  ----select * from #Calc_Past7 where itemname ='951883'-- in (select distinct itemname from #AllKeys_Past where itemname not in ( select ItemName from #Items))  
  
  --Save past weeks data (which are not re-calced this time) as a snapshot by current EsdVersionId and Current Stitch Ww  
  IF (NOT EXISTS (SELECT * FROM dbo.EsdSupplyByFgWeekSnapshot WHERE EsdVersionId = @EsdVersionId_Curr AND LastStitchYearWw = @StitchYearWw_Curr))  
  BEGIN  
   INSERT dbo.EsdSupplyByFgWeekSnapshot([EsdVersionId], [LastStitchYearWw], [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess],  
             [FgSupplyReqt], [MrbBonusback], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh],  
             [EohExcess], [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual],  
             Billings, [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock],  
             [SourceEsdVersionId], [StitchYearWw], [IsReset], [IsMonthRoll])  
    SELECT @EsdVersionId_Curr, @StitchYearWw_Curr, [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess],  
      [FgSupplyReqt], [MrbBonusback], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh],  
      [EohExcess], [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual],        Billings, [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock],  
      [EsdVersionId], [StitchYearWw], [IsReset], [IsMonthRoll]  
    FROM dbo.EsdSupplyByFgWeek  
    WHERE YearWw < @StartYearWw_Prev  
  END  
  
  -------------------- 9. Update Current and Future data to esd.EsdDataSupplyStitch  --------------------  
  -- Update Current and Future period calc to dbo.EsdSupplyByFgWeek  
  DELETE t  
  FROM dbo.EsdSupplyByFgWeekSnapshot t  
    INNER JOIN #Items i On i.ItemName = t.ItemName  
  WHERE EsdVersionId = @EsdVersionId_Curr AND LastStitchYearWw = @StitchYearWw_Curr AND YearWw >= @StartYearWw_Curr  
  
  --910394, 202021  
  INSERT INTO dbo.EsdSupplyByFgWeekSnapshot ([EsdVersionId], [LastStitchYearWw], [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt],   
            [MrbBonusBack], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh],   
            [EohExcess], [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual],   
            Billings, [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock],   
            SourceEsdVersionId, StitchYearWw, IsReset, IsMonthRoll )  
   SELECT DISTINCT @EsdVersionId_Curr, @StitchYearWw_Curr, [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt]  
     , [MrbBonusBack], [OneWoiBoh], [Eoh], [BohTarget], [SellableEOH]  
     , NULL AS [Calc_Sellable_EOH]  
     , [BohExcess], [SellableBOH], [EohExcess], DiscreteEohExcess   
     , ISNULL([MPSSellableSupply],0) + ISNULL([SupplyDelta],0) as [MPSSellableSupply]  
     , [SupplyDelta]   
     , NULL AS [NewEoh]   
     , NULL AS [EohInvTgt]  
     , NULL AS [TestOutActual]  
     , NULL AS [Billings]  
     , NULL AS [Eoh Target]  
     , NULL AS [SellableSupply]  
     , NULL AS [ExcessAdjust]  
     , NULL AS Scrapped  
     , NULL AS RMA  
     , NULL AS Rework  
     , NULL AS Blockstock  
     , @EsdVersionId_Curr AS SourceEsdVersionId, @StitchYearWw_Curr, @IsReset_Curr, @IsMonthRoll_Curr  
   FROM #Calc_Curr8  
   --where ItemName = '99ADWA'  
     
  --Add Non-MPS MM SupplyDelta - e.g BOX MMs - for @StartYearWw_Curr week only  
  IF (@IsMonthRoll_Curr = 1 AND @IsReset_Curr <> 1)  
  BEGIN  
   DELETE t  
   FROM dbo.EsdSupplyByFgWeekSnapshot t  
   WHERE EsdVersionId = @EsdVersionId_Curr AND LastStitchYearWw = @StitchYearWw_Curr  
     AND EXISTS (SELECT * FROM #NonMPSSupplyDelta i WHERE i.ItemName = t.ItemName AND i.YearWw = t.YearWw)  
  
   INSERT INTO dbo.EsdSupplyByFgWeekSnapshot ([EsdVersionId], [LastStitchYearWw], [ItemName], [YearWw], [WwId], [MPSSellableSupply], [SupplyDelta], SourceEsdVersionId, StitchYearWw, IsReset, IsMonthRoll )  
    SELECT  @EsdVersionId_Curr, @StitchYearWw_Curr, [ItemName], t.[YearWw], WwId   
      , [SupplyDelta] as [MPSSellableSupply]  
      , [SupplyDelta]  
      , @EsdVersionId_Curr AS SourceEsdVersionId, @StitchYearWw_Curr, @IsReset_Curr, @IsMonthRoll_Curr  
    FROM #NonMPSSupplyDelta t  
      INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = t.YearWw  
  END  
    
  -------------------- 10. Fetch Supply Excess FROM esd.EsdDataSupplyStitch for YearWw = @StartYearWw_Prev --------------------  
  -- Update Past period calc to esd.EsdDataSupplyStitch  
  -- Fetch Supply Excess to retain the Supply Excess in esd.EsdDataSupplyStitch  
  DROP TABLE IF EXISTS #Copy_SupplyDelta;  
  SELECT ItemName, YearWw, WwId, Sum(ISNULL([SupplyDelta], 0)) AS [SupplyDelta]  
  INTO #Copy_SupplyDelta  
  FROM dbo.EsdSupplyByFgWeek AS SupplyDelta  
  WHERE SupplyDelta.YearWw = @StartYearWw_Prev  
  GROUP BY ItemName, YearWw, WwId  
  -- SELECT * FROM #Copy_SupplyDelta;  
   
  DROP TABLE IF EXISTS #Calc_Past8;  
  SELECT DU.*  
    , SE.SupplyDelta AS SupplyDelta  
  INTO #Calc_Past8  
  FROM #Calc_Past7 AS DU  
    LEFT JOIN #Copy_SupplyDelta AS SE ON SE.ItemName = DU.ItemName AND SE.YearWw = DU.YearWw;  
  
  
  -------------------- 11. Update Past data to esd.EsdDataSupplyStitch --------------------  
  DELETE t  
  FROM dbo.EsdSupplyByFgWeekSnapshot  t  
  WHERE EsdVersionId = @EsdVersionId_Curr AND LastStitchYearWw = @StitchYearWw_Curr  
    AND EXISTS (SELECT * FROM #AllKeys_Past WHERE ItemName = t.ItemName)  
    AND YearWw < @StartYearWw_Curr  
    AND YearWw >= @StartYearWw_Prev  
  
  INSERT INTO dbo.EsdSupplyByFgWeekSnapshot ([EsdVersionId], [LastStitchYearWw], [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt],   
           [MrbBonusBack], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh], [EohExcess],   
           [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual], Billings,   
           [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock], SourceEsdVersionId  
           , StitchYearWw, IsReset, IsMonthRoll )  
   SELECT DISTINCT @EsdVersionId_Curr, @StitchYearWw_Curr, ItemName, YearWw, [WwId], OneWoi, TotalAdjWoi, [UnrestrictedBoh]  
     , NULL AS [WoiWithoutExcess]  
     , NULL AS [FgSupplyReqt]  
     , NULL AS [MrbBonusBack]  
     , [OneWoiBoh], [Eoh], [BohTarget]  
     , NULL AS [SellableEOH]  
     , [Calc_Sellable_EOH], [BohExcess], [SellableBOH], [EohExcess]  
     , [DiscreteEohExcess], [MPSSellableSupply], SupplyDelta, [NewEoh]  
     , NULL AS [EohInvTgt]  
     , [TestOutActual], Billings  
     , [Eoh Target], [SellableSupply], [ExcessAdjust], Scrapped, RMA, Rework, Blockstock, [EsdVersionID] AS SourceEsdVersionId, @StitchYearWw_Prev, @IsReset_Prev, @IsMonthRoll_Prev  
   FROM #Calc_Past8   
   WHERE YearWw >= @StartYearWw_Prev  
     AND YearWw < @StartYearWw_Curr  
  
  --Zero out SupplyDelta for all past weeks  
  UPDATE  dbo.EsdSupplyByFgWeekSnapshot  
  SET  [SupplyDelta] = 0  
  WHERE EsdVersionId = @EsdVersionId_Curr AND LastStitchYearWw = @StitchYearWw_Curr  
    AND YearWw < @StartYearWw_Curr  
  
  --MAIN LOGIC END  
  
  -- If user specifieds @IncludeMasterStitch, apply logic to update esd.EsdDataSupplyStitch -------------------------------------------------------------------------------------------  
  IF(@IncludeMasterStitch = 1)   
  BEGIN  
   -------------------- 9b. Update Current and Future data to esd.EsdDataSupplyStitch  --------------------  
   -- Update Current and Future period calc to esd.EsdDataSupplyStitch  
   DELETE t  
   FROM dbo.EsdSupplyByFgWeek t  
     INNER JOIN #Items i On i.ItemName = t.ItemName  
   WHERE YearWw >= @StartYearWw_Curr  
  
   --910394, 202021  
   INSERT INTO dbo.EsdSupplyByFgWeek ( [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt],   
             [MrbBonusBack], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh],   
             [EohExcess], [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual],   
             Billings, [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock],   
             [EsdVersionID], StitchYearWw, IsReset, IsMonthRoll )  
    SELECT DISTINCT [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt]  
      , [MrbBonusBack], [OneWoiBoh], [Eoh], [BohTarget], [SellableEOH]  
      , NULL AS [Calc_Sellable_EOH]  
      , [BohExcess], [SellableBOH], [EohExcess], DiscreteEohExcess   
      , ISNULL([MPSSellableSupply],0) + ISNULL([SupplyDelta],0) as [MPSSellableSupply]  
      , [SupplyDelta]   
      , NULL AS [NewEoh]   
      , NULL AS [EohInvTgt]  
      , NULL AS [TestOutActual]  
      , NULL AS [BillingsNetWithTMGUnits]  
      , NULL AS [Eoh Target]  
      , NULL AS [SellableSupply]  
      , NULL AS [ExcessAdjust]  
      , NULL AS Scrapped  
      , NULL AS RMA  
      , NULL AS Rework  
      , NULL AS Blockstock  
      , @EsdVersionId_Curr AS [EsdVersionId], @StitchYearWw_Curr, @IsReset_Curr, @IsMonthRoll_Curr  
    FROM #Calc_Curr8  
    --where ItemName = '99ADWA'  
     
   --Add Non-MPS MM SupplyDelta - e.g BOX MMs - for @StartYearWw_Curr week only  
   IF (@IsMonthRoll_Curr = 1 AND @IsReset_Curr <> 1)  
   BEGIN  
    DELETE t  
    FROM dbo.EsdSupplyByFgWeek t  
    WHERE EXISTS (SELECT * FROM #NonMPSSupplyDelta i WHERE i.ItemName = t.ItemName AND i.YearWw = t.YearWw)  
  
    INSERT INTO dbo.EsdSupplyByFgWeek ([ItemName], [YearWw], [WwId], [MPSSellableSupply], [SupplyDelta], [EsdVersionID], StitchYearWw, IsReset, IsMonthRoll )  
     SELECT  [ItemName], t.[YearWw], WwId   
       , [SupplyDelta] as [MPSSellableSupply]  
       , [SupplyDelta]  
       , @EsdVersionId_Curr AS [EsdVersionId], @StitchYearWw_Curr, @IsReset_Curr, @IsMonthRoll_Curr  
     FROM #NonMPSSupplyDelta t  
       INNER JOIN dbo.IntelCalendar ic ON ic.YearWw = t.YearWw  
   END  
    
   -------------------- 11. Update Past data to esd.EsdDataSupplyStitch --------------------  
   DELETE t  
   FROM dbo.EsdSupplyByFgWeek  t  
   WHERE EXISTS (SELECT * FROM #AllKeys_Past WHERE ItemName = t.ItemName)  
     AND YearWw < @StartYearWw_Curr  
     AND YearWw >= @StartYearWw_Prev  
  
   INSERT INTO dbo.EsdSupplyByFgWeek ( [ItemName], [YearWw], [WwId], [OneWoi], [TotalAdjWoi], [UnrestrictedBoh], [WoiWithoutExcess], [FgSupplyReqt],   
            [MrbBonusBack], [OneWoiBoh], [Eoh], [BohTarget], [SellableEoh], [CalcSellableEoh], [BohExcess], [SellableBoh], [EohExcess],   
            [DiscreteEohExcess], [MPSSellableSupply], [SupplyDelta], [NewEOH], [EohInvTgt], [TestOutActual], Billings,   
            [EohTarget], [SellableSupply], [ExcessAdjust], [Scrapped], [RMA], [Rework], [Blockstock], [EsdVersionID]  
            , StitchYearWw, IsReset, IsMonthRoll )  
    SELECT DISTINCT ItemName, YearWw, [WwId], OneWoi, TotalAdjWoi, [UnrestrictedBoh]  
      , NULL AS [WoiWithoutExcess]  
      , NULL AS [FgSupplyReqt]  
      , NULL AS [MrbBonusBack]  
      , [OneWoiBoh], [Eoh], [BohTarget]  
      , NULL AS [SellableEOH]  
      , [Calc_Sellable_EOH], [BohExcess], [SellableBOH], [EohExcess]  
      , [DiscreteEohExcess], [MPSSellableSupply], SupplyDelta, [NewEoh]  
      , NULL AS [EohInvTgt]  
      , [TestOutActual], Billings  
      , [Eoh Target], [SellableSupply], [ExcessAdjust], Scrapped, RMA, Rework, Blockstock, [EsdVersionID], @StitchYearWw_Prev, @IsReset_Prev, @IsMonthRoll_Prev  
    FROM #Calc_Past8   
    WHERE YearWw >= @StartYearWw_Prev  
      AND YearWw < @StartYearWw_Curr  
  
   --Zero out SupplyDelta for all past weeks  
   UPDATE  dbo.EsdSupplyByFgWeek  
   SET  [SupplyDelta] = 0  
   WHERE YearWw < @StartYearWw_Curr  
  END  
  
  RETURN 0;  
 END TRY  
 BEGIN CATCH  
  SELECT @ReturnErrorMessage =   
     'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50))   
     + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))    
     + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50))    
     + ' Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>')  
     + ' Procedure: ' + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>')   
     + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');  
  
  EXEC dbo.UspAddApplicationLog  
   @LogSource = 'Database'  
   , @LogType = 'Error'  
   , @Category = @ErrorLoggedBy  
   , @SubCategory = @ErrorLoggedBy  
   , @Message = @CurrentAction  
   , @Status = 'ERROR'  
   , @Exception = @ReturnErrorMessage  
   , @BatchId = @BatchId;  
  
  -- Send the exact exception to the caller  
  THROW;  
   
 END CATCH;  
END  