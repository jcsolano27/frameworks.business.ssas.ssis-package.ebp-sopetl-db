

CREATE PROC [dbo].[UspLoadChangeDemand] as

	DECLARE @CURRENTQUARTER INT;
	DECLARE @FUTUREQUARTER INT;
	
	SELECT @CURRENTQUARTER= (DATEPART(YEAR,GETDATE()) * 100) + DATEPART(QUARTER,DATEADD( QUARTER, DATEDIFF( QUARTER, 0, GETDATE()) - 2, 0));
	SELECT @FUTUREQUARTER = @CURRENTQUARTER + 200;
	
	SELECT [SnOPDemandForecastMonth], [SnOPDemandProductId], [YearQtr], [NewDemand], CreatedBy, ModifiedOn INTO #ManualChange FROM dbo.ChangeDemand WHERE [Demand] <> [NewDemand];

	TRUNCATE TABLE [dbo].[ChangeDemand];

	INSERT INTO [dbo].[ChangeDemand]
			   ([SnOPDemandForecastMonth]
			   ,[SnOPDemandProductId]
			   ,[SnOPDemandProductNm]
			   ,[YearQtr]
			   ,[NewDemand]
			   ,[Demand]
			   ,[ChangeType]
			   ,[ImpactIntelGoals]
			   ,[Concatenated]
	)
	SELECT 
		  [SnOPDemandForecastMonth]
		  ,D.[SnOPDemandProductId]
		  ,H.[SnOPDemandProductNm]
		  ,[YearQq]
		  ,SUM([Quantity]) Quantity
		  ,SUM([Quantity]) Quantity
		  ,'' "Change Type"
		  ,'' "Impact Intel Goals"
		  ,''
	FROM [SVD].[dbo].[SnOPDemandForecast] AS D
	JOIN (SELECT DISTINCT SnOPDemandProductId, [SnOPDemandProductNm] FROM [dbo].[StgProductHierarchy]) AS H
	ON D.SnOPDemandProductId = H.SnOPDemandProductId
	JOIN (SELECT DISTINCT YearMonth, YearQq FROM [dbo].[IntelCalendar]) C 
	ON C.YearMonth = D.YearMm
	where [ParameterId]=1
	AND [YearQq] BETWEEN @CURRENTQUARTER AND @FUTUREQUARTER
	GROUP BY 
		  [SnOPDemandForecastMonth]
		  ,D.[SnOPDemandProductId]
		  ,[YearQq]
		  ,H.[SnOPDemandProductNm]
	;

	UPDATE [dbo].[ChangeDemand] SET Concatenated = concat(SnOPDemandForecastMonth, YearQtr,SnOPDemandProductNm)
	UPDATE [dbo].[ChangeDemand] SET Change = 'N'; 

	-- ADDITION OF EMPTY PREVIOUS MONTHS
	DECLARE @PPQ INT;
	DECLARE @PQ INT;
	DECLARE @CM INT;
	DECLARE @PM INT;
	DECLARE @MQ INT;


	SELECT @PPQ = (DATEPART(YEAR,GETDATE()) * 100) + DATEPART(QUARTER,DATEADD( QUARTER, DATEDIFF( QUARTER, 0, GETDATE()) - 2, 0));
	SELECT @PQ = (DATEPART(YEAR,GETDATE()) * 100) + DATEPART(QUARTER,DATEADD( QUARTER, DATEDIFF( QUARTER, 0, GETDATE()) - 1, 0));

	SELECT @PM = DATEPART(YEAR,CAST(DATEADD(m, -1, GetDate()) as date)) * 100 + DATEPART(MONTH,CAST(DATEADD(m, -1, GetDate()) as date))
	SELECT @CM = (DATEPART(YEAR,GETDATE()) * 100) + DATEPART(MONTH,GETDATE());

	SELECT @MQ = MIN(YearQtr) FROM [dbo].[ChangeDemand] WHERE SnOPDemandForecastMonth = @CM;

	INSERT INTO [dbo].[ChangeDemand] (
		SnOPDemandForecastMonth,
		SnOpDemandProductId, 
		SnOpDemandProductNm, 
		YearQtr,
		Demand,
		NewDemand,
		Change,
		ChangeType,
		ImpactIntelGoals,
		Concatenated,
		ModifiedOn,
		CreatedBy
	)

	SELECT 
		SnOPDemandForecastMonth,
		SnOpDemandProductId, 
		SnOpDemandProductNm, 
		@PQ YearQtr,
		0 Demand,
		0 NewDemand,
		'N' Change,
		'' ChangeType,
		'' ImpactIntelGoals,
		Concatenated,
		ModifiedOn,
		CreatedBy
	FROM [dbo].[ChangeDemand] 
	WHERE YearQtr = @MQ
	AND SnOPDemandForecastMonth = @CM
	UNION
	SELECT 
		SnOPDemandForecastMonth,
		SnOpDemandProductId, 
		SnOpDemandProductNm, 
		@PPQ,
		0,
		0,
		'N',
		'',
		'',
		Concatenated,
		ModifiedOn,
		CreatedBy
	FROM [dbo].[ChangeDemand] 
	WHERE YearQtr = @MQ
	AND SnOPDemandForecastMonth = @CM
	UNION
	SELECT 
		@PM,
		SnOpDemandProductId, 
		SnOpDemandProductNm, 
		@PQ,
		0,
		0,
		'N',
		'',
		'',
		Concatenated,
		ModifiedOn,
		CreatedBy
	FROM [dbo].[ChangeDemand] 
	WHERE YearQtr = @MQ
	AND SnOPDemandForecastMonth = @PM
	UNION
	SELECT 
		@PM,
		SnOpDemandProductId, 
		SnOpDemandProductNm, 
		@PPQ,
		0,
		0,
		'N',
		'',
		'',
		Concatenated,
		ModifiedOn,
		CreatedBy
	FROM [dbo].[ChangeDemand] 
	WHERE YearQtr = @MQ
	AND SnOPDemandForecastMonth = @PM
	;

	Merge into [dbo].[ChangeDemand] D
	USING #ManualChange C
	ON  D.[SnOPDemandForecastMonth] = C.[SnOPDemandForecastMonth] AND
		D.[SnOPDemandProductId] = C.[SnOPDemandProductId] AND
		D.[YearQtr] = C.[YearQtr] 
	WHEN MATCHED THEN
		 UPDATE SET D.[NewDemand] = C.[NewDemand],
		 D.CreatedBy = C.CreatedBy,
		 D.ModifiedOn = C.ModifiedOn,
		 D.Change = 'Y'
	;

	DROP TABLE #ManualChange;

