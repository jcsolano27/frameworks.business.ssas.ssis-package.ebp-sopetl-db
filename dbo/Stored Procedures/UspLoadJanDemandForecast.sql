CREATE PROC [dbo].[UspLoadJanDemandForecast] as

	DECLARE @CURRENTMONTH INT;
	DECLARE @FUTUREMONTH INT;
	DECLARE @PlanningMonthDisplayName VARCHAR(50);
	DECLARE @DemandWw INT; 
	DECLARE @PlanningMonthId INT; 
	
	SELECT @CURRENTMONTH= (DATEPART(YEAR,GETDATE()) * 100) + 12;
	SELECT @FUTUREMONTH = (DATEPART(YEAR,GETDATE()) * 100) + 100 + 1;
	SELECT @DemandWw = (DATEPART(YEAR,GETDATE()) * 100) + 51;
	SELECT @PlanningMonthDisplayName = 'Jan ' + CAST(DATEPART(YEAR,GETDATE()) + 1 AS VARCHAR(5)); 
	SELECT @PlanningMonthId = MAX(PlanningMonthId) FROM DBO.PLANNINGMONTHS;

	-- INSERT A NEW ROW FOR JANUARY ON THE PLANNING MONTH TABLE

	INSERT INTO PLANNINGMONTHS(
		PlanningMonth,
		PlanningMonthId,
		PlanningMonthDisplayName,
		DemandWw,
		StrategyWw,
		ResetWw, 
		ReconWw,
		CreatedOn,
		CreatedBy
	)
	SELECT 
		@FUTUREMONTH,
		@PlanningMonthId + 1, 
		@PlanningMonthDisplayName,
		@DemandWw,
		Null,
		Null,
		Null,
		Getdate(),
		current_user
	FROM DBO.PLANNINGMONTHS
	WHERE 1 > (
		SELECT COUNT(1) 
		FROM 
		DBO.PLANNINGMONTHS
		WHERE PlanningMonth = @FUTUREMONTH
	)
	AND PlanningMonthId = @PlanningMonthId
	;

	-- INSERT CURRENT DECEMBER VERSION AS JANUARY VERSION

	INSERT INTO [dbo].[SnOPDemandForecast] 
	SELECT
		SourceApplicationName,
		@FUTUREMONTH SnOPDemandForecastMonth, 
		SnOPDemandProductId, 
		ProfitCenterCd,
		YearMm,
		ParameterId,
		Quantity,
		CreatedOn,
		current_user,
		Getdate()
	FROM [dbo].[SnOPDemandForecast] 
	WHERE SnOPDemandForecastMonth = @CURRENTMONTH
	AND 1 > 
	(
		SELECT COUNT(1) 
		FROM 
		[dbo].[SnOPDemandForecast] 
		WHERE SnOPDemandForecastMonth = @FUTUREMONTH
	)
	;