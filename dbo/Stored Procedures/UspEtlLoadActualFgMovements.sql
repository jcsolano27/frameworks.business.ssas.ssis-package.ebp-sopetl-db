CREATE   PROC [dbo].[UspEtlLoadActualFgMovements]

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from Fab MPS for selected Versions
*************************************************************************************/
BEGIN
	SET NOCOUNT ON
	DECLARE @BatchId VARCHAR(100) = 'ActualFgMovements.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
	DECLARE @EmailMessage VARCHAR(1000) ='ActualFgMovements Successful'
	DECLARE @Prog VARCHAR(255)

	BEGIN TRY
		--Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'ActualFgMovements', 'UspActualFgMovements','Load Items Data', 'BEGIN', NULL, @BatchId
CREATE TABLE #TEMP (
	SourceApplicationName VARCHAR(25), 
	ItemName VARCHAR(25),
	YearWw INT,
	MovementType VARCHAR(25),
	Quantity FLOAT,
	ModifiedOn DATETIME
);

DECLARE @StartYearWw INT = 202253 
		;WITH CTE_REWORK AS (
			SELECT SourceApplicationName, ItemName, YearWw, MovementType, (Q945+Q912-Q911) Quantity,ModifiedOn FROM 
			(
				SELECT 
					ISNULL(ISNULL(T1.SourceApplicationName,T2.SourceApplicationName),T3.SourceApplicationName) SourceApplicationName,
					ISNULL(ISNULL(T1.ItemName,T2.ItemName),T3.ItemName) ItemName, 
					ISNULL(ISNULL(T1.YearWw,T2.YearWw),T3.YearWw) YearWw, 
					'rework_qty' MovementType,
					ISNULL(T1.Quantity,0) Q945, 
					ISNULL(T2.Quantity,0) Q912, 
					ISNULL(T3.Quantity,0) Q911, 
					ISNULL(ISNULL(T1.LastUpdatedDtm,T2.LastUpdatedDtm),T3.LastUpdatedDtm) ModifiedOn
				FROM
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 945) T1
				FULL OUTER JOIN 
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 912) T2
				ON T1.ItemName = T2.ItemName 
				AND T1.YearWw = T2.YearWw
				FULL OUTER JOIN 
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 911) T3
				ON T1.ItemName = T3.ItemName 
				AND T1.YearWw = T3.YearWw
			) AS STG
			 WHERE STG.YearWw > @StartYearWw  
		),

		CTE_RMA AS (
			SELECT SourceApplicationName, ItemName, YearWw, MovementType, (Q941-Q942) Quantity,ModifiedOn FROM 
			(
				SELECT 
					ISNULL(T1.SourceApplicationName,T2.SourceApplicationName) SourceApplicationName,
					ISNULL(T1.ItemName,T2.ItemName) ItemName, 
					ISNULL(T1.YearWw,T2.YearWw) YearWw, 
					'rma_qty' MovementType,
					ISNULL(T1.Quantity,0) Q941, 
					ISNULL(T2.Quantity,0) Q942,  
					ISNULL(T1.LastUpdatedDtm,T2.LastUpdatedDtm) ModifiedOn
				FROM
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 941) T1
				FULL OUTER JOIN 
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 942) T2
				ON T1.ItemName = T2.ItemName 
				AND T1.YearWw = T2.YearWw
			) AS STG
			WHERE STG.YearWw > @StartYearWw  
		),
		CTE_SCRAP AS (
			SELECT SourceApplicationName, ItemName, YearWw, MovementType, (Q552-Q551) Quantity,ModifiedOn FROM 
			(
				SELECT 
					ISNULL(T1.SourceApplicationName,T2.SourceApplicationName) SourceApplicationName,
					ISNULL(T1.ItemName,T2.ItemName) ItemName, 
					ISNULL(T1.YearWw,T2.YearWw) YearWw, 
					'scrap_qty' MovementType,
					ISNULL(T1.Quantity,0) Q552, 
					ISNULL(T2.Quantity,0) Q551, 
					ISNULL(T1.LastUpdatedDtm,T2.LastUpdatedDtm) ModifiedOn
				FROM
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 552) T1
				FULL OUTER JOIN 
				(select * from [dbo].[StgActualFgMovements] WHERE MovementType = 551) T2
				ON T1.ItemName = T2.ItemName 
				AND T1.YearWw = T2.YearWw
			) AS STG
			WHERE STG.YearWw > @StartYearWw  
		),
		CTE_BLOCKSTOCK AS (
			SELECT SourceApplicationName, ItemName, YearWw, MovementType,SUM(Q343)-SUM(Q344) Quantity, MIN(ModifiedOn) as ModifiedOn
			FROM 
			(    
			SELECT     
				SourceApplicationName,    
				ItemName,     
				YearWw,     
				'blockstock_qty' MovementType,    
				CASE WHEN MovementType = 343 THEN ISNULL(Quantity,0) ELSE 0 END AS Q343,
				CASE WHEN MovementType = 344 THEN ISNULL(Quantity,0) ELSE 0 END AS Q344, 
				LastUpdatedDtm ModifiedOn    
			FROM  
				(
						SELECT * FROM [dbo].[StgActualFgMovements] WHERE MovementType = 343 AND OriginalDebitCreditInd = 'H'
						AND YearWw >  @StartYearWw  
								UNION     
						SELECT * FROM [dbo].[StgActualFgMovements] WHERE MovementType = 344 AND OriginalDebitCreditInd = 'H'
						AND YearWw  > @StartYearWw  
			)  AS STG  
			) S2
				GROUP BY SourceApplicationName, ItemName, YearWw, MovementType
		)
		INSERT INTO #TEMP
		SELECT
			SourceApplicationName,
			SUBSTRING(ItemName, PATINDEX('%[^0]%', ItemName+'.'), LEN(ItemName)) ItemName,
			YearWw,
			MovementType,
			Quantity,
			ModifiedOn
		FROM 
		(
		SELECT * FROM CTE_REWORK UNION
		SELECT * FROM CTE_RMA UNION
		SELECT * FROM CTE_SCRAP UNION
		SELECT * FROM CTE_BLOCKSTOCK
		) AS U;

		Merge [dbo].[ActualFgMovements] AS T
		USING 
		(
			SELECT 
				SourceApplicationName,
				ItemName,
				YearWw,
				MovementType,
				SUM(Quantity) Quantity,
				MIN(ModifiedOn) ModifiedOn
			FROM #TEMP M
			JOIN [dbo].[StgProductHierarchy] P
			ON P.FinishedGoodItemId = M.ItemName
			GROUP BY 		
				SourceApplicationName,
				ItemName,
				YearWw,
				MovementType
		) S
		ON 
		T.ItemName = S.ItemName
		AND T.YearWw = S.YearWw
		AND T.MovementType = S.MovementType
		WHEN NOT MATCHED BY TARGET THEN
		INSERT(SourceApplicationName,ItemName,YearWw,MovementType,Quantity,ModifiedOn)
		VALUES(S.SourceApplicationName,S.ItemName,S.YearWw,S.MovementType,S.Quantity,S.ModifiedOn)
		WHEN MATCHED THEN UPDATE SET
			T.[Quantity] = S.Quantity,
			T.ModifiedOn = S.ModifiedOn
		;

		DROP TABLE #TEMP;
		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'ActualFgMovements', 'UspActualFgMovements','Load Items Data', 'END', NULL, @BatchId
		
		--Send sucess email to MPS Recon support PDL
		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspActualFgMovements Successful'

	END TRY
	BEGIN CATCH 
		
		--Send failure email to MPS Recon support PDL 
		SET @Prog = ERROR_PROCEDURE();
		SET @EmailMessage='ActualFgMovements failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

		EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='ActualFgMovements Failed'

		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'ActualFgMovements','UspActualFgMovements', 'Load Items Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
END