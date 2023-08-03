
/****** Object:  StoredProcedure [sop].[UspLoadCapacity]    Script Date: 7/25/2023 11:21:59 AM ******/
--SET ANSI_NULLS ON
--GO
--SET QUOTED_IDENTIFIER ON
--GO
------/*********************************************************************************        

------    Purpose: THIS PROC IS USED TO LOAD DATA FROM CommitCapacity & EquippedCapacity TO [sop].[Capacity] TABLE      

------    Called by:  SSIS      

------ Parameters - @KeyFigureIdentificatorId      

------	[sop].[CONST_KeyFigureId_TmgfActualCommitCapacity]()	- TmgfActualCommitCapacity      
------	[sop].[CONST_KeyFigureId_TmgfActualEquippedCapacity]()	- TmgfActualEquippedCapacity      
------	999														- All Storage Tables      

------    Date		User            Description        
------***********************************************************************************        

------	2023-07-17	vitorsix		Initial Release      
------  2023-07-25  atairumx		Include Delete logic to CommitCapacity and EquippedCapacity
------  2023-08-02	psillosx	    Quantity is not null and <> 0

------***********************************************************************************/      

CREATE PROC [sop].[UspLoadCapacity]
(@KeyFigureId INT)
AS
DECLARE @PublishLogId INT =
        (
            SELECT MAX(PublishLogId)FROM SVD.[dbo].[SnOPCompassMRPFabRouting]
        );

DECLARE @ScenarioNm sysname =
        (
            SELECT ScenarioNm
            FROM sop.CapacitySourceVersion
            WHERE PublishLogId = @PublishLogId
        ),
        @SourceSystemId INT = (sop.CONST_SourceSystemId_Svd()),
        @CurrentPlanningMonth INT =
        (
            SELECT sop.fnGetPlanningMonth()
        );

DECLARE @CONST_KeyFigureId_TmgfActualCommitCapacity INT = [sop].[CONST_KeyFigureId_TmgfActualCommitCapacity](),
        @CONST_KeyFigureId_TmgfActualEquippedCapacity INT = [sop].[CONST_KeyFigureId_TmgfActualEquippedCapacity]();

DECLARE @PlanVersionId INT =
        (
            SELECT PlanVersionId
            FROM sop.PlanVersion
            WHERE PlanVersionNm = @ScenarioNm
        );

IF @KeyFigureId = @CONST_KeyFigureId_TmgfActualCommitCapacity
   OR @KeyFigureId = 999
BEGIN
    MERGE [sop].[Capacity] AS TARGET
    USING
    (
        SELECT
            PlanningMonthNbr,
            PlanVersionId,
            CorridorId,
            KeyFigureId,
            TimePeriodId,
            Quantity
        FROM (
            SELECT @CurrentPlanningMonth AS PlanningMonthNbr,
                @PlanVersionId AS PlanVersionId,
                C.CorridorId,
                @CONST_KeyFigureId_TmgfActualCommitCapacity AS KeyFigureId, --999  
                T.TimePeriodId,
                SUM(F.Quantity) AS Quantity
            FROM SVD.[dbo].[SnOPCompassMRPFabRouting] AS F
                INNER JOIN sop.Corridor AS C
                    ON F.FabProcess = C.CorridorNm
                INNER JOIN sop.TimePeriod AS T
                    ON T.SourceNm = 'WorkWeek'
                    AND T.YearWorkweekNbr = F.FiscalYearWorkWeekNbr
            WHERE F.ParameterTypeName = 'COMMITCAPACITY'
                AND F.PublishLogId = @PublishLogId
            GROUP BY C.CorridorId,
                    T.TimePeriodId
        ) AS GroupBy
        WHERE Quantity IS NOT NULL
            AND Quantity <> 0
    ) AS SOURCE
    ON TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
       AND TARGET.PlanVersionId = SOURCE.PlanVersionId
       AND TARGET.CorridorId = SOURCE.CorridorId
       AND TARGET.KeyFigureId = SOURCE.KeyFigureId
       AND TARGET.TimePeriodId = SOURCE.TimePeriodId
    WHEN NOT MATCHED BY TARGET THEN 
        INSERT
        (
            PlanningMonthNbr,
            PlanVersionId,
            CorridorId,
            KeyFigureId,
            TimePeriodId,
            Quantity
        )
        VALUES
        (SOURCE.PlanningMonthNbr, SOURCE.PlanVersionId, SOURCE.CorridorId, SOURCE.KeyFigureId, SOURCE.TimePeriodId,
         SOURCE.Quantity)
    WHEN MATCHED AND SOURCE.Quantity <> TARGET.Quantity THEN
        UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                   TARGET.ModifiedOnDtm = GETDATE(),
                   TARGET.ModifiedByNm = ORIGINAL_LOGIN()
	WHEN NOT MATCHED BY SOURCE AND TARGET.PlanningMonthNbr = @CurrentPlanningMonth
								AND TARGET.PlanVersionId = @PlanVersionId
								AND TARGET.KeyFigureId = @CONST_KeyFigureId_TmgfActualCommitCapacity
		THEN DELETE
	;


END;

IF @KeyFigureId = @CONST_KeyFigureId_TmgfActualEquippedCapacity
   OR @KeyFigureId = 999
BEGIN
    MERGE [sop].[Capacity] AS TARGET
    USING
    (
        SELECT
            PlanningMonthNbr,
            PlanVersionId,
            CorridorId,
            KeyFigureId,
            TimePeriodId,
            Quantity
        FROM (
            SELECT @CurrentPlanningMonth AS PlanningMonthNbr,
                @PlanVersionId AS PlanVersionId,
                C.CorridorId,
                @CONST_KeyFigureId_TmgfActualEquippedCapacity AS KeyFigureId, -- 999  
                T.TimePeriodId,
                SUM(F.Quantity) AS Quantity
            FROM SVD.[dbo].[SnOPCompassMRPFabRouting] AS F
                INNER JOIN sop.Corridor AS C
                    ON F.FabProcess = C.CorridorNm
                INNER JOIN sop.TimePeriod AS T
                    ON T.SourceNm = 'WorkWeek'
                    AND T.YearWorkweekNbr = F.FiscalYearWorkWeekNbr
            WHERE F.ParameterTypeName = 'EQUIPPEDCAPACITY'
                AND F.PublishLogId = @PublishLogId
            GROUP BY C.CorridorId,
                    T.TimePeriodId
        ) AS GroupBy
        WHERE Quantity IS NOT NULL
            AND Quantity <> 0
    ) AS SOURCE
    ON TARGET.PlanningMonthNbr = SOURCE.PlanningMonthNbr
       AND TARGET.PlanVersionId = SOURCE.PlanVersionId
       AND TARGET.CorridorId = SOURCE.CorridorId
       AND TARGET.KeyFigureId = SOURCE.KeyFigureId
       AND TARGET.TimePeriodId = SOURCE.TimePeriodId
    WHEN NOT MATCHED BY TARGET THEN
        INSERT
        (
            PlanningMonthNbr,
            PlanVersionId,
            CorridorId,
            KeyFigureId,
            TimePeriodId,
            Quantity
        )
        VALUES
        (SOURCE.PlanningMonthNbr, SOURCE.PlanVersionId, SOURCE.CorridorId, SOURCE.KeyFigureId, SOURCE.TimePeriodId,
         SOURCE.Quantity)
    WHEN MATCHED AND SOURCE.Quantity <> TARGET.Quantity THEN
        UPDATE SET TARGET.Quantity = SOURCE.Quantity,
                   TARGET.ModifiedOnDtm = GETDATE(),
                   TARGET.ModifiedByNm = ORIGINAL_LOGIN()
	WHEN NOT MATCHED BY SOURCE AND TARGET.PlanningMonthNbr = @CurrentPlanningMonth
								AND TARGET.PlanVersionId = @PlanVersionId
								AND TARGET.KeyFigureId = @CONST_KeyFigureId_TmgfActualEquippedCapacity
		THEN DELETE
	;

END;

-- LOG EXECUTION      
BEGIN
    EXEC dbo.UspAddApplicationLog @LogSource = 'SnOPCompassMRPFabRouting',
                                  @LogType = 'Info',
                                  @Category = 'SOP',
                                  @SubCategory = 'Capacity',
                                  @Message = 'Load Capacity data from SnOPCompassMRPFabRouting',
                                  @Status = 'END',
                                  @Exception = NULL,
                                  @BatchId = NULL;
END;
