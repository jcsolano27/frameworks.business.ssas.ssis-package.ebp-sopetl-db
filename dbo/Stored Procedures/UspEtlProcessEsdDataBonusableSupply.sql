CREATE   PROC [dbo].[UspEtlProcessEsdDataBonusableSupply]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @EsdVersionId INT
  , @SourceApplicationName VARCHAR(50) = 'ESD'
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = 'EsdVersionId=|GlobalConfig='

AS
----/*********************************************************************************
     
----    Purpose:        Processes data   
----                        Source:      [dbo].[StgEsdBonusableSupply]
----                        Destination: [dbo].[EsdBonusableSupply] / [dbo].[EsdBonusableSupplyExceptions]

----    Called by:      SSMS
         
----    Result sets:    None
     
----    Parameters:
----                    @Debug:
----                        1 - Will output some basic info with timestamps
----                        2 - Will output everything from 1, as well as rowcounts
         
----    Return Codes:   0   = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2022-08-29  atairumx        Initial Release
----	2022-09-23	hmanentx		Addition of columns VersionFiscalCalendarId and FiscalCalendarId from SopFiscalCalendar
----	2022-10-13	hmanentx		Update Load Logic of VersionFiscalCalendarId column from EsdBonusableSupply and EsdBonusableSupplyExceptions
----	2022-11-02	ivilanox		Add the dbo.items on the dupes inner join
----	2022-12-08	atairumx		Add condition to delete records in destination table (ESDBonusableSupply/ESDBonusableSupplyExceptions)
----	2022-12-10	egubbelx		Added condition in exceptions to filter products that are null or Unmapped
----	2022-12-29	hmanentx		Add logic to load 0-valued rows when the Product doesn`t have Qqs ahead of the current one
----	2022-12-29	hmanentx		Changed the load query from OneMps to fix values for ItemClass when talking about FG and DIE PREP
----	2023-03-31	Iverson, Hal	Remove duplicates from source
----	2023-07-28	hmanentx		Adding the logic to load the materialized table with data used to build [dbo].[v_EsdDataBonusableSupplyProfitCenterDistribution]
----*********************************************************************************/

BEGIN

	SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

	SET NUMERIC_ROUNDABORT OFF;

	BEGIN TRY

		/*debug
		declare  @Debug TINYINT = 0
		, @BatchId VARCHAR(100) = NULL
		, @EsdVersionId INT = 163
		, @SourceApplicationName VARCHAR(50) = 'ESD'
		, @BatchRunId INT = 3915
		, @ParameterList VARCHAR(1000) = 'EsdVersionId=163|GlobalConfig=1'
		*/

		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
			, @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
			, @CurrentAction      VARCHAR(4000)
			, @DT                 VARCHAR(50)  = SYSDATETIME()
			, @Message            VARCHAR(MAX);

		SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

		SET @SourceApplicationName = 'ESD';

		IF (@BatchId IS NULL) BEGIN
			SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();
		END

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = 'Etl'
			, @SubCategory = @ErrorLoggedBy
			, @Message = @Message
			, @Status = 'BEGIN'
			, @Exception = NULL
			, @BatchId = @BatchId;

		-- used in calculations
		DECLARE
			@minYyyyQq INT
			, @maxYyyyQq INT
			, @i         INT

		-- Remove duplicates from source
		DROP TABLE IF EXISTS #ToRemove
		CREATE TABLE #ToRemove
		(
			ItemName VARCHAR(50) NOT NULL
			,ItemDescription VARCHAR(100) NULL
		);

		INSERT INTO #ToRemove
		SELECT DISTINCT
			Item
			,RIGHT(ItemName,15) AS Last10
		FROM [fabmpsrepldata].[SDA_Reporting].[dbo].[t_Excess_FabMps]
		WHERE 1 = 1
		AND TotalIsExcess = 0

		DELETE a
		FROM [dbo].[StgEsdBonusableSupply] a
		JOIN #ToRemove b ON a.ItemName = b.ItemName AND b.ItemDescription = RIGHT(a.ItemDescription,15) 
		WHERE
			EsdVersionId = @EsdVersionId
			AND ExcessToMpsInvTargetCum = 0

		-- Remove duplicates from source end

		-- Adding Rows that are not there with zeros excess
		DROP TABLE IF EXISTS #QuartersMissingZerosAdd

		SELECT DISTINCT 
			Bonus.EsdVersionId
			,Bonus.SourceApplicationName
			,Bonus.SourceVersionId
			,Bonus.ResetWw
			,Bonus.WhatIfScenarioName
			,Bonus.SdaFamily
			,Bonus.ItemName
			,Bonus.ItemClass
			,Bonus.ItemDescription
			,Bonus.SnOPDemandProductNm
			,Null AS Bonus
			,NULL AS Comment
			,Quarters.YearQq
			,0 AS ExcessToMpsInvTargetCum
		INTO #QuartersMissingZerosAdd
		FROM [dbo].[StgEsdBonusableSupply] Bonus
		CROSS JOIN (
			SELECT DISTINCT YearQq
			FROM [dbo].[StgEsdBonusableSupply] 
			WHERE EsdVersionId = @EsdVersionId) Quarters
		WHERE
			EsdVersionId = @EsdVersionId
			AND ItemName NOT IN (
				SELECT ItemName
				FROM (
					SELECT
						ItemName
						,SUM(ExcessToMpsInvTargetCum) AS Excess 
					FROM [dbo].[StgEsdBonusableSupply]
					WHERE EsdVersionId = @EsdVersionId
					GROUP BY ItemName) p
				WHERE Excess = 0)

		DELETE FROM Mza
		FROM #QuartersMissingZerosAdd Mza
		INNER JOIN [dbo].[StgEsdBonusableSupply] Bonus2
			ON  Mza.EsdVersionId = Bonus2.EsdVersionId
			AND Mza.ResetWw      = Bonus2.ResetWw
			AND Mza.ItemName     = Bonus2.ItemName
			AND Mza.YearQq       = Bonus2.YearQq

		INSERT INTO [dbo].[StgEsdBonusableSupply] 
		SELECT 
			EsdVersionId
			,SourceApplicationName
			,SourceVersionId
			,ResetWw
			,WhatIfScenarioName
			,SdaFamily
			,ItemName
			,ItemClass
			,ItemDescription
			,SnOPDemandProductNm
			,Bonus
			,Comment
			,YearQq
			,ExcessToMpsInvTargetCum
			,GetDate() AS CreatedOn
			,original_login() AS Createdby
		FROM #QuartersMissingZerosAdd MZ
		WHERE NOT EXISTS (
						SELECT 1 
						FROM [dbo].[StgEsdBonusableSupply] Stg 
						WHERE
							stg.ItemName = MZ.ItemName
							AND stg.EsdVersionId = MZ.EsdVersionId
							AND stg.YearQq = MZ.YearQq)

		DROP TABLE IF EXISTS #EsdDataBonusableSupply
		CREATE TABLE #EsdDataBonusableSupply
		(
			EsdVersionId INT NOT NULL
			, SourceApplicationName VARCHAR(25) NOT NULL
			, SourceVersionId INT NOT NULL
			, ResetWw INT NOT NULL
			, WhatIfScenarioName VARCHAR(50) NOT NULL
			, SdaFamily VARCHAR(50) NULL
			, ItemName VARCHAR(50) NOT NULL
			, ItemClass VARCHAR(25) NULL
			, ItemDescription VARCHAR(100) NULL
			, SnOPDemandProductNm VARCHAR(100) NULL
			, SnOPDemandProductId VARCHAR(100) NOT NULL
			, BonusPercent FLOAT NULL
			, Comments VARCHAR(MAX) NULL
			, YearQq INT NOT NULL
			, ExcessToMpsInvTargetCum FLOAT NULL
			, Process VARCHAR(50) NULL
			, YearMm INT NULL
			, BonusableDiscreteExcess FLOAT NULL
			, NonBonusableDiscreteExcess FLOAT NULL
			, ExcessToMpsInvTarget FLOAT NULL
			, BonusableCum FLOAT NULL
			, NonBonusableCum FLOAT NULL
			, VersionFiscalCalendarId INT NULL
			, FiscalCalendarId int NULL
			, RowNum INT NOT NULL
			, PRIMARY KEY CLUSTERED (ItemName, SnOPDemandProductId, YearQq, RowNum)
		);

		DROP TABLE IF exists #EsdDataBonusableSupplyExceptions
		CREATE TABLE #EsdDataBonusableSupplyExceptions
		(
			EsdVersionId INT NOT NULL
			, SourceApplicationName VARCHAR(25) NOT NULL
			, SourceVersionId INT NOT NULL
			, ResetWw INT NOT NULL
			, WhatIfScenarioName VARCHAR(50) NOT NULL
			, SdaFamily VARCHAR(50) NULL
			, ItemName VARCHAR(50) NOT NULL
			, ItemClass VARCHAR(25) NULL
			, ItemDescription VARCHAR(100) NULL
			, SnOPDemandProductNm VARCHAR(100) NULL
			, SnOPDemandProductId VARCHAR(100) NOT NULL
			, BonusPercent FLOAT NULL
			, Comments VARCHAR(MAX) NULL
			, YearQq INT NOT NULL
			, ExcessToMpsInvTargetCum FLOAT NULL
			, YearMm INT NULL
			, BonusableDiscreteExcess FLOAT NULL
			, NonBonusableDiscreteExcess FLOAT NULL
			, ExcessToMpsInvTarget FLOAT NULL
			, BonusableCum FLOAT NULL
			, NonBonusableCum FLOAT NULL
			, VersionFiscalCalendarId INT NULL
			, FiscalCalendarId int NULL
			, RowNum INT NOT NULL
			, PRIMARY KEY CLUSTERED (ItemName, YearQq, RowNum)
		);
	
		--Items Table
		DROP TABLE IF EXISTS #Items
		CREATE TABLE #Items
		(
			ItemName VARCHAR (18) NOT NULL,
			SnOPDemandProductId INT NULL,
			PRIMARY KEY CLUSTERED (ItemName)
		);

		INSERT INTO #Items
		( 
			ItemName, 
			SnOPDemandProductId
		)
		(
			SELECT
				ItemName,
				SnOPDemandProductId
			FROM dbo.Items_Manual
			UNION
			SELECT DISTINCT
				I.ItemName,
				I.SnOPDemandProductId
			FROM dbo.Items I
			WHERE
				I.ItemName NOT IN (SELECT ItemName FROM dbo.Items_Manual)
				AND I.IsActive = 1
		);
     
		-- Getting Duplicates
		WITH Dupes AS
		(
			SELECT
				s.EsdVersionId
				, s.SourceApplicationName
				, s.SourceVersionId
				, s.ResetWw
				, s.WhatIfScenarioName
				, s.SdaFamily
				, CASE WHEN s.ItemName = '' THEN s.ItemDescription ELSE s.ItemName END AS ItemName
				, s.ItemClass
				, s.ItemDescription
				, s.SnOPDemandProductNm
				, s.BonusPercent
				, s.Comments
				, s.YearQq
				, ExcessToMpsInvTargetCum = s.ExcessToMpsInvTargetCum * 1000.0
				, s.CreatedOn
				, s.CreatedBy
				, RowNum = ROW_NUMBER() OVER (
												PARTITION BY
													s.EsdVersionId
													, s.SourceApplicationName
													, s.ItemName
													, s.ItemDescription
													, s.SnOPDemandProductNm
													, s.YearQq
												ORDER BY
													s.ItemName
													, s.YearQq)
			FROM [dbo].[StgEsdBonusableSupply] s
			WHERE
				s.EsdVersionId = @EsdVersionId
				AND s.SourceApplicationName = @SourceApplicationName
		)       		

		INSERT INTO #EsdDataBonusableSupply
		(
			[EsdVersionId]
			,[SourceApplicationName]
			,[SourceVersionId]
			,[ResetWw]
			,[WhatIfScenarioName]
			,[SdaFamily]
			,[ItemName]
			,[ItemClass]
			,[ItemDescription]
			,[SnOPDemandProductNm]
			,[SnOPDemandProductId]
			,[BonusPercent]
			,[Comments]
			,[YearQq]
			,[ExcessToMpsInvTargetCum]
			,[Process]
			,[VersionFiscalCalendarId]
			,[RowNum]
		)
		( 
			SELECT
				stg.[EsdVersionId]
				,stg.[SourceApplicationName]
				,stg.[SourceVersionId]
				,stg.[ResetWw]
				,stg.[WhatIfScenarioName]
				,stg.[SdaFamily]
				,stg.[ItemName]
				,'FG' AS [ItemClass]
				,stg.[ItemDescription]
				,ISNULL(stg.SnOPDemandProductNm, '')
				,I.[SnOPDemandProductId] AS [SnOPDemandProductId]
				,stg.[BonusPercent]
				,stg.[Comments]
				,stg.[YearQq]
				,stg.[ExcessToMpsInvTargetCum]
				,hie.[SnOPProcessNm] AS [Process]
				,SOP.FiscalCalendarIdentifier AS VersionFiscalCalendarId
				,stg.RowNum
			FROM Dupes stg
			INNER JOIN #Items I ON stg.ItemName = I.ItemName
			INNER JOIN [dbo].[SnOPDemandProductHierarchy] hie	ON I.SnOPDemandProductId = hie.[SnOPDemandProductId]
			LEFT JOIN dbo.SvdSourceVersion SSV					ON SSV.SourceVersionId = stg.EsdVersionId
			LEFT JOIN dbo.SopFiscalCalendar SOP					ON SOP.FiscalYearMonthNbr = SSV.PlanningMonth AND SOP.SourceNm = 'Month'
			WHERE stg.[ItemClass] IN ('FG','FINISH')

			UNION
	
			SELECT
				stg.[EsdVersionId]
				,stg.[SourceApplicationName]
				,stg.[SourceVersionId]
				,stg.[ResetWw]
				,stg.[WhatIfScenarioName]
				,stg.[SdaFamily]
				,stg.[ItemName]
				,'DIE PREP' AS [ItemClass]
				,stg.[ItemDescription]
				,ISNULL(stg.SnOPDemandProductNm, '')
				,hie.[SnOPDemandProductId] AS [SnOPDemandProductId]
				,stg.[BonusPercent]
				,stg.[Comments]
				,stg.[YearQq]
				,stg.[ExcessToMpsInvTargetCum]
				,hie.[SnOPProcessNm] AS [Process]
				,SOP.FiscalCalendarIdentifier AS VersionFiscalCalendarId
				,stg.RowNum
			FROM Dupes stg
			INNER JOIN [dbo].[SnOPDemandProductHierarchy] hie	ON stg.SnOPDemandProductNm = hie.[SnOPDemandProductNm] AND hie.IsActive = 1
			LEFT JOIN dbo.SvdSourceVersion SSV					ON SSV.SourceVersionId = stg.EsdVersionId
			LEFT JOIN dbo.SopFiscalCalendar SOP					ON SOP.FiscalYearMonthNbr = SSV.PlanningMonth AND SOP.SourceNm = 'Month'
			WHERE
				stg.[ItemClass] IN ('DIE PREP','DIEPREP')
				AND ISNULL(stg.SnOPDemandProductNm, '') <> ''
		);

		--Table Exceptions Validations
		WITH DupesExceptions AS
		(
			SELECT
				s.EsdVersionId
				, s.SourceApplicationName
				, s.SourceVersionId
				, s.ResetWw
				, s.WhatIfScenarioName
				, s.SdaFamily
				, CASE WHEN s.ItemName = '' THEN s.ItemDescription ELSE s.ItemName END AS ItemName
				, s.ItemClass
				, s.ItemDescription
				, s.SnOPDemandProductNm
				, s.BonusPercent
				, s.Comments
				, s.YearQq
				, ExcessToMpsInvTargetCum = s.ExcessToMpsInvTargetCum * 1000.0
				, s.CreatedOn
				, s.CreatedBy
				, RowNum = ROW_NUMBER() OVER (
												PARTITION BY
													s.EsdVersionId
													, s.SourceApplicationName
													, s.ItemName
													, s.ItemDescription
													, s.YearQq
												ORDER BY
													s.ItemName
													, s.YearQq)
			FROM [dbo].[StgEsdBonusableSupply] s
			WHERE
				s.EsdVersionId = @EsdVersionId
				AND s.SourceApplicationName = @SourceApplicationName
		)

		INSERT INTO #EsdDataBonusableSupplyExceptions
		(
			EsdVersionId
			, SourceApplicationName
			, SourceVersionId
			, ResetWw
			, WhatIfScenarioName
			, SdaFamily
			, ItemName
			, ItemClass
			, ItemDescription
			, SnOPDemandProductNm
			, SnOPDemandProductId
			, BonusPercent
			, Comments
			, YearQq
			, ExcessToMpsInvTargetCum
			, VersionFiscalCalendarId
			, RowNum
		)
		SELECT
			de.EsdVersionId
			, de.SourceApplicationName
			, de.SourceVersionId
			, de.ResetWw
			, de.WhatIfScenarioName
			, de.SdaFamily
			, de.ItemName
			, de.ItemClass
			, de.ItemDescription
			, de.SnOPDemandProductNm
			, CONVERT(INT, itm.[SnOPDemandProductId]) AS [SnOPDemandProductId]
			, de.BonusPercent
			, de.Comments
			, de.YearQq
			, de.ExcessToMpsInvTargetCum
			, SOP.FiscalCalendarIdentifier AS VersionFiscalCalendarId
			, de.RowNum
		FROM DupesExceptions de	
		INNER JOIN [dbo].[Items] itm					ON de.[ItemName] = itm.ItemName AND itm.IsActive=1
		LEFT JOIN [dbo].SnOPDemandProductHierarchy DP	ON itm.SnOPDemandProductid = DP.SnOPDemandProductid
		LEFT JOIN dbo.SvdSourceVersion SSV				ON SSV.SourceVersionId = de.EsdVersionId
		LEFT JOIN dbo.SopFiscalCalendar SOP				ON SOP.FiscalYearMonthNbr = SSV.PlanningMonth AND SOP.SourceNm = 'Month'
		WHERE
			(dp.SnOPDemandProductNm IS NULL OR dp.SnOPDemandProductNm LIKE '%Unmapped%')
	
		-- Removing duplicates - Table
		DELETE #EsdDataBonusableSupply
		WHERE RowNum > 1

		-- Removing duplicates - Table Exceptions
		DELETE #EsdDataBonusableSupplyExceptions
		WHERE RowNum > 1;

		------> Inserting The Zero-Based Rows for the next two Quarters in the Products that don`t have it
		DROP TABLE IF EXISTS #NextTwoQuarters
		DROP TABLE IF EXISTS #EsdDataBonusableSupplyMaxQuarter
		DROP TABLE IF EXISTS #EsdDataBonusableSupplyZeroQuarters

		-- Getting the next 2 quarters
		SELECT TOP 3
			R.YearQq
			,R.YearMm
		INTO #NextTwoQuarters
		FROM (
			SELECT
				YearQq,
				MAX(YearMonth) AS YearMm
			FROM dbo.IntelCalendar
			WHERE StartDate > GETDATE()
			GROUP BY YearQq
		) AS R
		ORDER BY 1 ASC

		-- Getting the MAX quarters for each Product
		SELECT
			EsdVersionId
			,ResetWw
			,ItemName
			,SnOPDemandProductId
			,MAX(YearQq) AS MAX_YearQq
		INTO #EsdDataBonusableSupplyMaxQuarter
		FROM #EsdDataBonusableSupply
		GROUP BY
			EsdVersionId
			,ResetWw
			,ItemName
			,SnOPDemandProductId

		-- Remove all the cases that already have the next two Quarters
		DELETE FROM E
		FROM #EsdDataBonusableSupplyMaxQuarter E
		WHERE E.MAX_YearQq >= (SELECT MAX(YearQq) FROM #NextTwoQuarters)

		-- Create the dataset with the zero values
		SELECT DISTINCT
			E.EsdVersionId
			,E.SourceApplicationName
			,E.SourceVersionId
			,E.ResetWw
			,E.WhatIfScenarioName
			,E.SdaFamily
			,E.ItemName
			,E.ItemClass
			,E.ItemDescription
			,E.SnOPDemandProductNm
			,E.SnOPDemandProductId
			,E.BonusPercent
			,E.Comments
			,N.YearQq
			,0 AS ExcessToMpsInvTargetCum -- Zero-Based Value
			,E.Process
			,N.YearMm
			,0 AS BonusableDiscreteExcess
			,0 AS NonBonusableDiscreteExcess
			,0 AS ExcessToMpsInvTarget
			,0 AS BonusableCum
			,0 AS NonBonusableCum
			,SOP.FiscalCalendarIdentifier AS VersionFiscalCalendarId
			,sfc.FiscalCalendarIdentifier AS FiscalCalendarId
			,E.RowNum
		INTO #EsdDataBonusableSupplyZeroQuarters
		FROM #EsdDataBonusableSupply E
		INNER JOIN #EsdDataBonusableSupplyMaxQuarter EQ
													ON E.EsdVersionId			= EQ.EsdVersionId
													AND E.ResetWw				= EQ.ResetWw
													AND E.ItemName				= EQ.ItemName
													AND E.SnOPDemandProductId	= EQ.SnOPDemandProductId
		CROSS JOIN #NextTwoQuarters N
		LEFT JOIN dbo.SopFiscalCalendar sfc			ON sfc.FiscalYearMonthNbr = N.YearMm AND sfc.SourceNm = 'Month'
		LEFT JOIN dbo.SvdSourceVersion SSV			ON SSV.SourceVersionId = EQ.EsdVersionId
		LEFT JOIN dbo.SopFiscalCalendar SOP			ON SOP.FiscalYearMonthNbr = SSV.PlanningMonth AND SOP.SourceNm = 'Month'

		-- Remove from datasets the YearQqs that already exists
		DELETE FROM ZQ
		FROM #EsdDataBonusableSupplyZeroQuarters ZQ
		INNER JOIN #EsdDataBonusableSupply EQ
										ON EQ.EsdVersionId			= ZQ.EsdVersionId
										AND EQ.ResetWw				= ZQ.ResetWw
										AND EQ.ItemName				= ZQ.ItemName
										AND EQ.SnOPDemandProductId	= ZQ.SnOPDemandProductId
										AND EQ.YearQq				= ZQ.YearQq

		-- Insert the remaining rows into the insert final table
		INSERT INTO #EsdDataBonusableSupply
		SELECT
			EsdVersionId
			,SourceApplicationName
			,SourceVersionId
			,ResetWw
			,WhatIfScenarioName
			,SdaFamily
			,ItemName
			,ItemClass
			,ItemDescription
			,SnOPDemandProductNm
			,SnOPDemandProductId
			,BonusPercent
			,Comments
			,YearQq
			,ExcessToMpsInvTargetCum -- Zero-Based Value
			,Process
			,YearMm
			,BonusableDiscreteExcess
			,NonBonusableDiscreteExcess
			,ExcessToMpsInvTarget
			,BonusableCum
			,NonBonusableCum
			,VersionFiscalCalendarId
			,FiscalCalendarId
			,RowNum
		FROM #EsdDataBonusableSupplyZeroQuarters

		--  Calculations *********************************************************************************************
		SELECT @CurrentAction = 'Performing calculations';

		SELECT
			@minYyyyQq = MIN(YearQq)
			, @maxYyyyQq = MAX(YearQq)
		FROM #EsdDataBonusableSupply;

		DROP TABLE IF EXISTS #Calendar
		CREATE TABLE #Calendar
		(
			PrevYyyyQq INT NOT NULL
			, YyyyQq INT NOT NULL PRIMARY KEY CLUSTERED
			, NextYyyyQq INT NOT NULL
			, Yyyymm INT NOT NULL
		);

		INSERT INTO #Calendar (PrevYyyyQq, YyyyQq, NextYyyyQq, Yyyymm)
		SELECT
			PrevYyyyQq = 
				CASE
					WHEN IntelQuarter = 1 THEN (IntelYear - 1) * 100 + 4
					ELSE IntelYear * 100 + IntelQuarter - 1
				END
			, YyyyQq = IntelYear * 100 + IntelQuarter
			, NextYyyyQq =
				CASE
					WHEN IntelQuarter = 4 THEN (IntelYear + 1) * 100 + 1
					ELSE IntelYear * 100 + IntelQuarter + 1
				END
			, MAX(IntelYear * 100 + IntelMonth) Yyyymm
		FROM [dbo].[IntelCalendar]
		WHERE IntelYear * 100 + IntelQuarter BETWEEN @minYyyyQq AND @maxYyyyQq
		GROUP BY
			IntelYear
			, IntelQuarter;

		UPDATE f
		SET
			f.YearMm = C.Yyyymm
			, f.BonusableCum = (f.BonusPercent * f.ExcessToMpsInvTargetCum)
			, f.NonBonusableCum = (1 - f.BonusPercent) * f.ExcessToMpsInvTargetCum
		FROM #EsdDataBonusableSupply f
		INNER JOIN #Calendar C ON f.YearQq = C.YyyyQq;

		SELECT @i = @minYyyyQq;

		WHILE @i <= @maxYyyyQq BEGIN
			UPDATE s1
			SET
				s1.ExcessToMpsInvTarget = s1.ExcessToMpsInvTargetCum - ISNULL(s2.ExcessToMpsInvTargetCum, 0)
				, s1.BonusableDiscreteExcess = s1.BonusableCum - ISNULL(s2.BonusableCum, 0)
				, s1.NonBonusableDiscreteExcess = s1.NonBonusableCum - ISNULL(s2.NonBonusableCum, 0)
			FROM #EsdDataBonusableSupply s1
			INNER JOIN #Calendar c					ON c.YyyyQq = s1.YearQq
			LEFT JOIN #EsdDataBonusableSupply s2	ON s2.ItemName = s1.ItemName AND s2.YearQq = c.PrevYyyyQq
			WHERE s1.YearQq = @i;

			SELECT @i = NextYyyyQq
			FROM #Calendar
			WHERE YyyyQq = @i;
		END;

		--Table Exception -------------------------------------------------------------------------------------------
		UPDATE f
		SET
			f.YearMm = C.Yyyymm
			, f.BonusableCum = (f.BonusPercent * f.ExcessToMpsInvTargetCum)
			, f.NonBonusableCum = (1 - f.BonusPercent) * f.ExcessToMpsInvTargetCum
		FROM #EsdDataBonusableSupplyExceptions f
		INNER JOIN #Calendar C ON f.YearQq = C.YyyyQq;
    
		SELECT @i = @minYyyyQq;

		WHILE @i <= @maxYyyyQq BEGIN
			UPDATE s1
			SET
				s1.ExcessToMpsInvTarget = s1.ExcessToMpsInvTargetCum - ISNULL(s2.ExcessToMpsInvTargetCum, 0)
				, s1.BonusableDiscreteExcess = s1.BonusableCum - ISNULL(s2.BonusableCum, 0)
				, s1.NonBonusableDiscreteExcess = s1.NonBonusableCum - ISNULL(s2.NonBonusableCum, 0)
			FROM #EsdDataBonusableSupplyExceptions s1
			INNER JOIN #Calendar c							ON c.YyyyQq = s1.YearQq
			LEFT JOIN #EsdDataBonusableSupplyExceptions s2	ON s2.ItemName = s1.ItemName AND s2.YearQq = c.PrevYyyyQq
			WHERE s1.YearQq = @i;

			SELECT @i = NextYyyyQq
			FROM #Calendar
			WHERE YyyyQq = @i;
		END;
    
		-- Updating FiscalCalendarId based on the YearMm calculated column
		UPDATE S
		SET S.FiscalCalendarId = sfc.FiscalCalendarIdentifier
		FROM #EsdDataBonusableSupply S
		LEFT JOIN dbo.SopFiscalCalendar sfc ON sfc.FiscalYearMonthNbr = S.YearMm AND sfc.SourceNm = 'Month'

		UPDATE S
		SET S.FiscalCalendarId = sfc.FiscalCalendarIdentifier
		FROM #EsdDataBonusableSupplyExceptions S
		LEFT JOIN dbo.SopFiscalCalendar sfc ON sfc.FiscalYearMonthNbr = S.YearMm AND sfc.SourceNm = 'Month'

		-- Removing the ItemNames NULL
		DROP TABLE IF EXISTS #EsdDataBonusableSupplyItemNameNull

		SELECT * 
		INTO #EsdDataBonusableSupplyItemNameNull
		FROM #EsdDataBonusableSupply
		WHERE COALESCE(Itemname,'') = ''

		DELETE FROM #EsdDataBonusableSupply WHERE COALESCE(Itemname,'') = ''

		--ONLY ITEMNAME NOT NULL
		MERGE [dbo].[EsdBonusableSupply] AS BS --Destination Table
		USING #EsdDataBonusableSupply AS STG --Source Table
		ON
		(
			BS.EsdVersionId					= STG.EsdVersionId
			AND BS.ResetWw					= STG.ResetWw
			AND BS.ItemName					= STG.ItemName
			AND BS.SdaFamily				= STG.SdaFamily
			AND BS.ItemClass				= STG.ItemClass
			AND BS.YearQq					= STG.YearQq
			AND BS.SnOPDemandProductID		= STG.SnOPDemandProductID
		)		 	
		WHEN MATCHED THEN
			UPDATE SET
				BS.SourceApplicationName			= STG.SourceApplicationName
				, BS.SnOPDemandProductId			= STG.SnOPDemandProductId
				, BS.SourceVersionId				= STG.SourceVersionId
				, BS.WhatIfScenarioName				= STG.WhatIfScenarioName
				, BS.ItemDescription				= STG.ItemDescription
				, BS.Process						= STG.Process
				, BS.BonusPercent					= STG.BonusPercent
				, BS.Comments						= STG.Comments
				, BS.ExcessToMpsInvTargetCum		= STG.ExcessToMpsInvTargetCum
				, BS.BonusableDiscreteExcess		= STG.BonusableDiscreteExcess
				, BS.NonBonusableDiscreteExcess		= STG.NonBonusableDiscreteExcess
				, BS.ExcessToMpsInvTarget			= STG.ExcessToMpsInvTarget
				, BS.BonusableCum					= STG.BonusableCum
				, BS.NonBonusableCum				= STG.NonBonusableCum
				, BS.VersionFiscalCalendarId		= STG.VersionFiscalCalendarId
				, BS.FiscalCalendarId				= STG.FiscalCalendarId
				, BS.YearMm							= STG.YearMm
				, BS.Createdon						= getdate()
				, BS.CreatedBy						= original_login()
		WHEN NOT MATCHED BY TARGET THEN
			INSERT VALUES
			(
				STG.EsdVersionId,
				STG.SourceApplicationName,
				STG.SourceVersionId,
				STG.ResetWw,
				STG.WhatIfScenarioName,
				STG.SdaFamily,
				STG.ItemName,
				STG.ItemClass,
				STG.ItemDescription,
				STG.SnOPDemandProductId,
				STG.BonusPercent,
				STG.Comments,
				STG.YearQq,
				STG.ExcessToMpsInvTargetCum,
				STG.Process,
				STG.YearMm,
				STG.BonusableDiscreteExcess,
				STG.NonBonusableDiscreteExcess,
				STG.ExcessToMpsInvTarget,
				STG.BonusableCum,
				STG.NonBonusableCum,
				getdate(),
				original_login(),
				STG.VersionFiscalCalendarId,
				STG.FiscalCalendarId
			)
		WHEN NOT MATCHED BY SOURCE AND BS.EsdVersionId = @EsdVersionId
			THEN DELETE;
			   		 	  	   
		----ONLY ITEMNAME NULL
		MERGE [dbo].[EsdBonusableSupply] AS BS --Destination Table
		USING #EsdDataBonusableSupplyItemNameNull AS STG --Source Table
		ON
		(
			BS.EsdVersionId					= STG.EsdVersionId
			AND BS.ResetWw					= STG.ResetWw	
			AND BS.SnOPDemandProductId		= STG.SnOPDemandProductId
			AND BS.SdaFamily				= STG.SdaFamily
			AND BS.ItemClass				= STG.ItemClass
			AND BS.YearQq					= STG.YearQq	
			AND BS.ItemName					= STG.ItemName		
		)		 	
		WHEN MATCHED THEN
			UPDATE SET	
				BS.SourceApplicationName			= STG.SourceApplicationName
				, BS.ItemName						= STG.ItemName
				, BS.SourceVersionId				= STG.SourceVersionId
				, BS.WhatIfScenarioName				= STG.WhatIfScenarioName
				, BS.ItemDescription				= STG.ItemDescription
				, BS.Process						= STG.Process
				, BS.BonusPercent					= STG.BonusPercent
				, BS.Comments						= STG.Comments
				, BS.ExcessToMpsInvTargetCum		= STG.ExcessToMpsInvTargetCum
				, BS.BonusableDiscreteExcess		= STG.BonusableDiscreteExcess
				, BS.NonBonusableDiscreteExcess		= STG.NonBonusableDiscreteExcess
				, BS.ExcessToMpsInvTarget			= STG.ExcessToMpsInvTarget
				, BS.BonusableCum					= STG.BonusableCum
				, BS.NonBonusableCum				= STG.NonBonusableCum
				, BS.VersionFiscalCalendarId		= STG.VersionFiscalCalendarId
				, BS.FiscalCalendarId				= STG.FiscalCalendarId
				, BS.YearMm							= STG.YearMm
				, BS.Createdon						= getdate()
				, BS.CreatedBy						= original_login()
		WHEN NOT MATCHED BY TARGET THEN
		INSERT VALUES
		(
			STG.EsdVersionId,
			STG.SourceApplicationName,
			STG.SourceVersionId,
			STG.ResetWw,
			STG.WhatIfScenarioName,
			STG.SdaFamily,
			STG.ItemName,
			STG.ItemClass,
			STG.ItemDescription,
			STG.SnOPDemandProductId,
			STG.BonusPercent,
			STG.Comments,
			STG.YearQq,
			STG.ExcessToMpsInvTargetCum,
			STG.Process,
			STG.YearMm,
			STG.BonusableDiscreteExcess,
			STG.NonBonusableDiscreteExcess,
			STG.ExcessToMpsInvTarget,
			STG.BonusableCum,
			STG.NonBonusableCum,
			getdate(),
			original_login(),
			STG.VersionFiscalCalendarId,
			STG.FiscalCalendarId
		)
		WHEN NOT MATCHED BY SOURCE AND COALESCE(BS.ItemName, '') = '' AND BS.EsdVersionId = @EsdVersionId
			THEN DELETE;

		MERGE [dbo].[EsdBonusableSupplyExceptions] AS BSE --Destination Table
		USING #EsdDataBonusableSupplyExceptions AS STG --Source Table
		ON
		(
			BSE.EsdVersionId				= STG.EsdVersionId
			AND BSE.ItemName				= STG.ItemName
			AND BSE.YearQq					= STG.YearQq
		)
		WHEN MATCHED THEN
			UPDATE SET
				BSE.SourceApplicationName			= STG.SourceApplicationName
				, BSE.SourceVersionId				= STG.SourceVersionId
				, BSE.ResetWw						= STG.ResetWw
				, BSE.YearMm						= STG.YearMm 
				, BSE.WhatIfScenarioName			= STG.WhatIfScenarioName
				, BSE.SdaFamily						= STG.SdaFamily
				, BSE.ItemClass						= STG.ItemClass
				, BSE.ItemDescription				= STG.ItemDescription
				, BSE.SnOPDemandProductId			= STG.SnOPDemandProductId 
				, BSE.BonusPercent					= STG.BonusPercent
				, BSE.Comments						= STG.Comments
				, BSE.ExcessToMpsInvTargetCum		= STG.ExcessToMpsInvTargetCum
				, BSE.BonusableDiscreteExcess		= STG.BonusableDiscreteExcess
				, BSE.NonBonusableDiscreteExcess	= STG.NonBonusableDiscreteExcess
				, BSE.ExcessToMpsInvTarget			= STG.ExcessToMpsInvTarget
				, BSE.BonusableCum					= STG.BonusableCum
				, BSE.NonBonusableCum				= STG.NonBonusableCum
				, BSE.VersionFiscalCalendarId		= STG.VersionFiscalCalendarId
				, BSE.FiscalCalendarId				= STG.FiscalCalendarId
				, BSE.Createdon						= getdate()
				, BSE.CreatedBy						= original_login()						
		WHEN NOT MATCHED BY TARGET THEN
			INSERT VALUES
			(
				STG.EsdVersionId,
				STG.SourceApplicationName,
				STG.SourceVersionId,
				STG.ResetWw,
				STG.WhatIfScenarioName,
				STG.SdaFamily,
				STG.ItemName,
				STG.ItemClass,
				STG.ItemDescription,
				STG.SnOPDemandProductId,
				STG.BonusPercent,
				STG.Comments,
				STG.YearQq,
				STG.ExcessToMpsInvTargetCum,
				STG.YearMm,
				STG.BonusableDiscreteExcess,
				STG.NonBonusableDiscreteExcess,
				STG.ExcessToMpsInvTarget,
				STG.BonusableCum,
				STG.NonBonusableCum,
				getdate(),
				original_login(),
				STG.VersionFiscalCalendarId,
				STG.FiscalCalendarId
			)
		WHEN NOT MATCHED BY SOURCE AND BSE.EsdVersionId = @EsdVersionId
			THEN DELETE;

		-- Adding the data from the view dbo.v_EsdDataBonusableSupplyProfitCenterDistribution to the materialized table
		DROP TABLE IF EXISTS #SvdVersions
		SELECT
			PlanningMonth
			,MAX(SourceVersionId) AS SourceVersionId
		INTO #SvdVersions
		FROM dbo.SvdSourceVersion SSV
		WHERE SvdSourceApplicationId = dbo.CONST_SvdSourceApplicationId_Esd()
		GROUP BY PlanningMonth

		DROP TABLE IF EXISTS #PcSupply
		SELECT
			sd.SnOPDemandProductId,
			sd.YearQq,
			sd.ProfitCenterCd,
			sd.SourceVersionId as EsdVersionId,
			sd.Quantity AS ProfitCenterQuantity,
			SSV.SvdSourceVersionId
		INTO #PcSupply
		FROM dbo.SupplyDistributionByQuarter sd
		JOIN dbo.[Parameters] p					ON sd.SupplyParameterId			= p.ParameterId
		JOIN dbo.SnOPDemandProductHierarchy dp	ON sd.SnOPDemandProductId		= dp.SnOPDemandProductId
		JOIN #SvdVersions C						ON C.PlanningMonth				= sd.PlanningMonth AND C.SourceVersionId = sd.SourceVersionId
		JOIN dbo.SvdSourceVersion SSV
												ON SSV.PlanningMonth			= C.PlanningMonth
												AND SSV.SourceVersionId			= C.SourceVersionId
												AND SSV.SvdSourceApplicationId	= dbo.CONST_SvdSourceApplicationId_Esd()
		WHERE
			sd.SourceApplicationId = dbo.CONST_SourceApplicationId_ESD()
			AND P.ParameterId = dbo.CONST_ParameterId_SosFinalUnrestrictedEoh()

		DROP TABLE IF EXISTS #PcSupplyConsolidated
		SELECT
			SnOPDemandProductId,
			YearQq,
			ProfitCenterCd,
			EsdVersionId,
			COUNT(ProfitCenterQuantity) OVER (PARTITION BY EsdVersionId, SnOPDemandProductId, YearQq) AS ProfitCenterCount,
			ProfitCenterQuantity / NULLIF(SUM(ProfitCenterQuantity) OVER (PARTITION BY EsdVersionId, SnOPDemandProductId, YearQq), 0) AS ProfitCenterPct,
			SvdSourceVersionId
		INTO #PcSupplyConsolidated
		FROM #PcSupply

		CREATE NONCLUSTERED INDEX IX_001_PcSupplyConsolidated ON #PcSupplyConsolidated(SnOPDemandProductId, YearQq, EsdVersionId)
		CREATE NONCLUSTERED INDEX IX_002_PcSupplyConsolidated ON #PcSupplyConsolidated(ProfitCenterCd)

		DELETE FROM #PcSupplyConsolidated
		WHERE ProfitCenterCount = 0

		TRUNCATE TABLE dbo.EsdDataBonusableSupplyProfitCenterDistribution
		
		INSERT INTO dbo.EsdDataBonusableSupplyProfitCenterDistribution
		(
			YearQq
			,YearMm
			,ResetWw
			,VersionFiscalCalendarId
			,FiscalCalendarId
			,EsdVersionId
			,SourceVersionId
			,SvdSourceVersionId
			,ProfitCenterCd
			,ProfitCenterHierarchyId
			,SnOPDemandProductId
			,SourceApplicationName
			,ItemName
			,ItemClass
			,ItemDescription
			,SdaFamily
			,SuperGroupNm
			,WhatIfScenarioName
			,Comments
			,Process
			,TypeData
			,BonusableDiscreteExcess
			,BonusPercent
			,ExcessToMpsInvTargetCum
			,NonBonusableCum
			,NonBonusableDiscreteExcess
			,ProfitCenterPct
		)
		SELECT
			R.YearQq
			,R.YearMm
			,R.ResetWw
			,R.VersionFiscalCalendarId
			,R.FiscalCalendarId
			,R.EsdVersionId
			,R.SourceVersionId
			,R.SvdSourceVersionId
			,R.ProfitCenterCd
			,R.ProfitCenterHierarchyId
			,R.SnOPDemandProductId
			,R.SourceApplicationName
			,R.ItemName
			,R.ItemClass
			,R.ItemDescription
			,R.SdaFamily
			,R.SuperGroupNm
			,R.WhatIfScenarioName
			,R.Comments
			,R.Process
			,R.TypeData
			,R.BonusableDiscreteExcess
			,R.BonusPercent
			,R.ExcessToMpsInvTargetCum
			,R.NonBonusableCum
			,R.NonBonusableDiscreteExcess
			,R.ProfitCenterPct
		FROM (
			SELECT
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount)								AS ProfitCenterPct,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableCum				AS NonBonusableCum,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableDiscreteExcess	AS NonBonusableDiscreteExcess,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * ExcessToMpsInvTargetCum		AS ExcessToMpsInvTargetCum,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * BonusableDiscreteExcess		AS BonusableDiscreteExcess,
				pc.ProfitCenterCd,
				h.SuperGroupNm,
				bs.EsdVersionId,
				bs.SourceApplicationName,
				bs.SourceVersionId,
				bs.ResetWw,
				bs.WhatIfScenarioName,
				bs.SdaFamily,
				bs.ItemName,
				bs.ItemClass,
				bs.ItemDescription,
				bs.SnOPDemandProductId,
				bs.BonusPercent,
				bs.Comments,
				bs.YearQq,
				bs.Process,
				bs.YearMm,
				bs.VersionFiscalCalendarId,
				bs.FiscalCalendarId,
				'BonusableSupply' AS TypeData,
				h.ProfitCenterHierarchyId,
				pc.SvdSourceVersionId
			FROM dbo.EsdBonusableSupply bs
			INNER JOIN #PcSupplyConsolidated pc
													ON bs.SnOPDemandProductId	= pc.SnOPDemandProductId
													AND bs.YearQq				= pc.YearQq
													AND bs.esdversionId			= pc.EsdVersionId
			INNER JOIN dbo.ProfitCenterHierarchy h	ON pc.ProfitCenterCd		= h.ProfitCenterCd
			UNION
			SELECT 
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount)									AS ProfitCenterPct,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableCum				AS NonBonusableCum,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * NonBonusableDiscreteExcess	AS NonBonusableDiscreteExcess,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * ExcessToMpsInvTargetCum		AS ExcessToMpsInvTargetCum,
				COALESCE(ProfitCenterPct, 1.0/ProfitCenterCount) * BonusableDiscreteExcess		AS BonusableDiscreteExcess,
				pc.ProfitCenterCd,
				h.SuperGroupNm,
				bse.EsdVersionId,
				bse.SourceApplicationName,
				bse.SourceVersionId,
				bse.ResetWw,
				bse.WhatIfScenarioName,
				bse.SdaFamily,
				bse.ItemName,
				bse.ItemClass,
				bse.ItemDescription,
				bse.SnOPDemandProductId,
				bse.BonusPercent,
				bse.Comments,
				bse.YearQq,
				NULL AS Process,
				bse.YearMm,
				bse.VersionFiscalCalendarId,
				bse.FiscalCalendarId,
				'BonusableSupplyExceptions' AS TypeData,
				h.ProfitCenterHierarchyId,
				pc.SvdSourceVersionId
			FROM dbo.EsdBonusableSupplyExceptions bse
			INNER JOIN #PcSupplyConsolidated pc
													ON bse.SnOPDemandProductId	= pc.SnOPDemandProductId
													AND bse.YearQq				= pc.YearQq
													AND bse.EsdVersionId		= pc.EsdVersionId
			INNER JOIN dbo.ProfitCenterHierarchy h	ON pc.ProfitCenterCd		= h.ProfitCenterCd
		) AS R

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = 'Etl'
			, @SubCategory = @ErrorLoggedBy
			, @Message = @Message
			, @Status = 'END'
			, @Exception = NULL
			, @BatchId = @BatchId;

		RETURN 0;

	END TRY
	BEGIN CATCH

		SELECT
		@ReturnErrorMessage =
		'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
		+ ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
		+ ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
		+ ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


		EXEC dbo.UspAddApplicationLog
		@LogSource = 'Database'
		, @LogType = 'Error'
		, @Category = 'Etl'
		, @SubCategory = @ErrorLoggedBy
		, @Message = @CurrentAction
		, @Status = 'ERROR'
		, @Exception = @ReturnErrorMessage
		, @BatchId = @BatchId;

		--re-throw the error
		THROW;

	END CATCH;

END