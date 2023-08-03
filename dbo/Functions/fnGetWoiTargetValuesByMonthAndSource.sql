CREATE   FUNCTION [dbo].[fnGetWoiTargetValuesByMonthAndSource]
(
	@SupplySourceTable varchar(50)
	,@SourceVersionId int
	,@PlanningMonth int
	,@SnOPDemandProductId int
	,@YearWw int = NULL
)
RETURNS @WOITargetValuesByMonthAndSource TABLE
(
	PlanningMonth int
	,SourceApplicationId int
	,SourceVersionId int
	,SnOPDemandProductId int
	,YearWw int
	,Quantity float
	,PRIMARY KEY (PlanningMonth, SourceApplicationId, SourceVersionId, SnOPDemandProductId, YearWw)
)
AS
----/*********************************************************************************
----    Purpose: Generate dataset from WoiTarget table to be used in Supply Distribution process.
----    Sources: [dbo].[SnOPDemandProductWoiTarget]
----    Destinations: [dbo].[SupplyDistribution]

----    Called by:      SSIS
         
----    Result sets:
/*
		RETURNS @WOITargetValuesByMonthAndSource TABLE
		(
			PlanningMonth int
			,SnOPDemandProductId int
			,YearWw int
			,Quantity float
		)
*/

----    Parameters:
--				@SupplySourceTable: defines if the source is asking for ESD or HDMR/NONHDMR data.
--				@SourceVersionId: specific version that is being loaded in the SupplyDistribution table.
--				@PlanningMonth: specific month that is being loaded in the SupplyDistribution table.
--				@SnOPDemandProductId: specific product that is being loaded in the SupplyDistribution table.
--				@YearWw: optional, specific workweek for a given ESD version.

----    Return Codes:   0 = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-04-12  hmanentx        Initial Release

----*********************************************************************************/
/* Testing harness
	select * from dbo.[fnGetWOITargetValuesByMonthAndSource]
		(
		'dbo.TargetSupply'
		,909
		,202212
		,1001042
		,202302
		)
--*/
BEGIN

	-- Common Variable Declaration
	DECLARE
		@CONST_SvdSourceApplicationId_Hdmr  INT = [dbo].[CONST_SvdSourceApplicationId_Hdmr]()
		,@CONST_SvdSourceApplicationId_NonHdmr INT = [dbo].[CONST_SvdSourceApplicationId_NonHdmr]()
		,@CONST_SvdSourceApplicationId_Esd  INT = [dbo].[CONST_SvdSourceApplicationId_Esd]()
		,@CONST_SourceApplicationId_Compass  INT = [dbo].[CONST_SourceApplicationId_Compass]()
		,@SvdSourceApplicationId int
		,@FirstSDAWwByEsdVersion int
		,@LastSDAWwByEsdVersion int
		,@EsdVersionId int
		,@PublishLogId int

	-- Table Variable Declaration
	DECLARE @EsdVersionWOI_Horizon TABLE (
			PlanningMonth int
			,SourceApplicationId int
			,SourceVersionId int
			,SnOPDemandProductId int
			,YearWw int
			,Quantity float
	)
	DECLARE @EsdVersionWOI_SDA TABLE (
			PlanningMonth int
			,SourceApplicationId int
			,SourceVersionId int
			,SnOPDemandProductId int
			,YearWw int
			,Quantity float
	)
	DECLARE @EsdVersionWOI_MRP TABLE (
			PlanningMonth int
			,SourceApplicationId int
			,SourceVersionId int
			,SnOPDemandProductId int
			,YearWw int
			,Quantity float
	)
	
	IF (@SupplySourceTable = 'dbo.EsdTotalSupplyAndDemandByDpWeek') BEGIN

		-- Get Start and End of Horizon for the ESD Version
		SELECT
			@FirstSDAWwByEsdVersion = MIN(HorizonStartYearWw)
			,@LastSDAWwByEsdVersion = MIN(HorizonEndYearww)
		FROM dbo.EsdSourceVersions E
		WHERE E.EsdVersionId = @SourceVersionId

		-- Get the PublishLogId for this EsdVersion
		SELECT @PublishLogId = SourceVersionId
		FROM dbo.EsdSourceVersions E
		WHERE E.EsdVersionId = @SourceVersionId
		AND E.SourceApplicationId = @CONST_SourceApplicationId_Compass
		
		/*
		Data Load for ESD Versions
		We`ll have three different kinds of loads
		1 - Historical Horizon: bring all HDMR and Non-HDMR data from the Full Target SVD Source Versions from each of the last 3 quarters.
		2 - SDA Horizon (Same as MPS): bring all the HDMR and Non-HDMR data from the Full Target SVD Source Versions for the current quarter and next year.
										See the rule of UspLoadEsdTotalSupplyAndDemandByDpWeek procedure.
		3 - MRP Horizon: All the data after SDA period. Get the versions in the EsdVersions table and load all the data from WoiTarget that comes
										from Compass.
		*/

		-- 1 - Historical Horizon
		IF @YearWw < @FirstSDAWwByEsdVersion BEGIN

			-- HDMR
			;WITH CTE_PlanningMonthsWithoutResetWw AS
			(
				SELECT
					PM.PlanningMonth
					,(SELECT MAX(PlanningMonth) FROM dbo.PlanningMonths PM2 WHERE PM2.PlanningMonth < PM.PlanningMonth) AS PriorPlanningMonth
				FROM dbo.PlanningMonths PM
				WHERE PM.ResetWw IS NULL
			)
			,CTE_MaxVersionByMonth AS
			(
				SELECT
					SV.PlanningMonth
					,MAX(SV.SourceVersionId) AS SourceVersionId
					,IC.YearWw
				FROM dbo.SvdSourceVersion SV
				INNER JOIN dbo.IntelCalendar IC ON IC.YearMonth = SV.PlanningMonth
				WHERE
					SV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Hdmr
					AND SV.SourceVersionType = 'Full_Target'
					AND IC.YearWw <> @FirstSDAWwByEsdVersion
					AND IC.YearWw <> @LastSDAWwByEsdVersion
				GROUP BY SV.PlanningMonth, IC.YearWw
				UNION ALL
				SELECT
					PM.PriorPlanningMonth
					,MAX(SV.SourceVersionId) AS SourceVersionId
					,IC.YearWw
				FROM CTE_PlanningMonthsWithoutResetWw PM
				INNER JOIN dbo.IntelCalendar IC ON IC.YearMonth = PM.PlanningMonth
				INNER JOIN dbo.SvdSourceVersion SV ON SV.PlanningMonth = PM.PriorPlanningMonth
				WHERE
					SV.SourceVersionType = 'Full_Target'
					AND SV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Hdmr
				GROUP BY PM.PriorPlanningMonth, IC.YearWw
			)
			INSERT INTO @EsdVersionWOI_Horizon
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			INNER JOIN CTE_MaxVersionByMonth CM
											ON CM.PlanningMonth = WT.PlanningMonth
											AND CM.SourceVersionId = WT.SourceVersionId
											AND CM.YearWw = WT.YearWw
			WHERE
				WT.PlanningMonth < @PlanningMonth
				AND WT.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Hdmr
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.YearWw = @YearWw

			-- NON-HDMR
			;WITH CTE_PlanningMonthsWithoutResetWw AS
			(
				SELECT
					PM.PlanningMonth
					,(SELECT MAX(PlanningMonth) FROM dbo.PlanningMonths PM2 WHERE PM2.PlanningMonth < PM.PlanningMonth) AS PriorPlanningMonth
				FROM dbo.PlanningMonths PM
				WHERE PM.ResetWw IS NULL
			)
			,CTE_MaxVersionByMonth AS (
				SELECT
					SV.PlanningMonth
					,MAX(SV.SourceVersionId) AS SourceVersionId
					,IC.YearWw
				FROM dbo.SvdSourceVersion SV
				INNER JOIN dbo.IntelCalendar IC ON IC.YearMonth = SV.PlanningMonth
				WHERE
					SV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NonHdmr
					AND SV.SourceVersionType = 'FullBuildTargetQty'
					AND IC.YearWw <> @FirstSDAWwByEsdVersion
					AND IC.YearWw <> @LastSDAWwByEsdVersion
				GROUP BY SV.PlanningMonth, IC.YearWw
				UNION ALL
				SELECT
					PM.PriorPlanningMonth
					,MAX(SV.SourceVersionId) AS SourceVersionId
					,IC.YearWw
				FROM CTE_PlanningMonthsWithoutResetWw PM
				INNER JOIN dbo.IntelCalendar IC ON IC.YearMonth = PM.PlanningMonth
				INNER JOIN dbo.SvdSourceVersion SV ON SV.PlanningMonth = PM.PriorPlanningMonth
				WHERE
					SV.SourceVersionType = 'FullBuildTargetQty'
					AND SV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NonHdmr
				GROUP BY PM.PriorPlanningMonth, IC.YearWw
			)
			INSERT INTO @EsdVersionWOI_Horizon
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			INNER JOIN CTE_MaxVersionByMonth CTE
												ON CTE.PlanningMonth = WT.PlanningMonth
												AND CTE.SourceVersionId = WT.SourceVersionId
												AND CTE.YearWw = WT.YearWw
			LEFT JOIN @EsdVersionWOI_Horizon H
											ON H.PlanningMonth = WT.PlanningMonth
											AND H.SnOPDemandProductId = WT.SnOPDemandProductId
											AND H.YearWw = WT.YearWw
			WHERE
				WT.PlanningMonth < @PlanningMonth
				AND WT.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NonHdmr
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.YearWw = @YearWw
				AND H.Quantity IS NULL

		END

		ELSE IF (@YearWw >= @FirstSDAWwByEsdVersion AND @YearWw <= @LastSDAWwByEsdVersion) BEGIN
			-- 2 - SDA Horizon
		
			-- HDMR
			;WITH CTE_MaxVersionByMonth AS
			(
				SELECT
					SV.PlanningMonth
					,MAX(SV.SourceVersionId) AS SourceVersionId
				FROM dbo.SvdSourceVersion SV
				INNER JOIN dbo.IntelCalendar IC ON IC.YearMonth = SV.PlanningMonth
				WHERE
					SV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Hdmr
					AND SV.SourceVersionType = 'Full_Target'
				GROUP BY SV.PlanningMonth
			)
			INSERT INTO @EsdVersionWOI_SDA
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			INNER JOIN CTE_MaxVersionByMonth CM
											ON CM.PlanningMonth = WT.PlanningMonth
											AND CM.SourceVersionId = WT.SourceVersionId
			WHERE
				WT.PlanningMonth = @PlanningMonth
				AND WT.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Hdmr
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.YearWw = @YearWw

			-- NON-HDMR
			;WITH CTE_MaxVersionByMonth AS (
				SELECT
					SV.PlanningMonth
					,MAX(SV.SourceVersionId) AS SourceVersionId
				FROM dbo.SvdSourceVersion SV
				INNER JOIN dbo.IntelCalendar IC ON IC.YearMonth = SV.PlanningMonth
				WHERE
					SV.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NonHdmr
					AND SV.SourceVersionType = 'FullBuildTargetQty'
				GROUP BY SV.PlanningMonth
			)
			INSERT INTO @EsdVersionWOI_SDA
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			INNER JOIN CTE_MaxVersionByMonth CTE
												ON CTE.PlanningMonth = WT.PlanningMonth
												AND CTE.SourceVersionId = WT.SourceVersionId
			LEFT JOIN @EsdVersionWOI_SDA H
											ON H.PlanningMonth = WT.PlanningMonth
											AND H.SnOPDemandProductId = WT.SnOPDemandProductId
											AND H.YearWw = WT.YearWw
			WHERE
				WT.PlanningMonth = @PlanningMonth
				AND WT.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NonHdmr
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.YearWw = @YearWw
				AND H.Quantity IS NULL

		END

		ELSE IF @YearWw >= @LastSDAWwByEsdVersion BEGIN

			-- 3 - MRP Horizon
			INSERT INTO @EsdVersionWOI_MRP
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			WHERE
				WT.SourceVersionId = @PublishLogId
				AND WT.PlanningMonth = @PlanningMonth
				AND WT.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.YearWw = @YearWw

		END

		-- Insert all data into the final table
		INSERT INTO @WOITargetValuesByMonthAndSource
		SELECT * FROM @EsdVersionWOI_Horizon
		UNION
		SELECT * FROM @EsdVersionWOI_SDA
		UNION
		SELECT * FROM @EsdVersionWOI_MRP

		-- Change the final table to reflect the current month
		UPDATE @WOITargetValuesByMonthAndSource
		SET PlanningMonth = @PlanningMonth

	END

	ELSE IF (@SupplySourceTable = 'dbo.TargetSupply') BEGIN

		-- Data Load for HDMR/Non-HDMR Versions
		SELECT
			@SvdSourceApplicationId = SvdSourceApplicationId
		FROM dbo.SvdSourceVersion S
		WHERE S.SourceVersionId = @SourceVersionId

		IF (@SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Hdmr) BEGIN

			-- Data Load for HDMR Versions
			INSERT INTO @WOITargetValuesByMonthAndSource
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			WHERE
				WT.PlanningMonth = @PlanningMonth
				AND WT.SvdSourceApplicationId = @SvdSourceApplicationId
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.SourceVersionId = @SourceVersionId
				AND WT.YearWw = @YearWw

		END

		ELSE IF (@SvdSourceApplicationId = @CONST_SvdSourceApplicationId_NonHdmr) BEGIN

			-- Data Load for Non-HDMR Versions
			INSERT INTO @WOITargetValuesByMonthAndSource
			SELECT
				WT.PlanningMonth
				,WT.SourceApplicationId
				,WT.SourceVersionId
				,WT.SnOPDemandProductId
				,WT.YearWw
				,WT.Quantity
			FROM dbo.SnOPDemandProductWoiTarget WT
			WHERE
				WT.PlanningMonth = @PlanningMonth
				AND WT.SvdSourceApplicationId = @SvdSourceApplicationId
				AND WT.SnOPDemandProductId = @SnOPDemandProductId
				AND WT.SourceVersionId = @SourceVersionId
				AND WT.YearWw = @YearWw

		END

	END

    RETURN

END
