CREATE VIEW [dbo].[v_EsdCompassExcess] AS



		SELECT 
			'Compass' AS SdaFamilies
			,1234 AS Version
			, NULL AS McpForExcess
			 , CompEx.[ItemId] AS Item
			,CompEx.[ItemId] AS ItemName
			, 'DIE PREP' AS [ItemClass]
			,NULL AS ItemGroupWafer
			  ,Cal.YearMonth AS YearMonth
			  ,0 AS DeltaExcess
			  ,CompEx.[DieEsuExcess]/1000 AS TotalExcess
		  FROM [dbo].[CompassDieEsuExcess] CompEx
		  JOIN dbo.GuiUIEsdVersion EsdVersion
		  ON CompEx.EsdVersionId = EsdVersion.EsdVersionId
		  JOIN
				(
				SELECT YearQq,YearMonth, MAX(YearWw) AS YearWw FROM dbo.intelcalendar
				WHERE YearWw IN 
				(
				SELECT YearWw FROM (
				SELECT YearQQ, MAX(YearWw) AS YearWw FROM dbo.intelcalendar
				GROUP BY YearQQ) LastWeekInQTR
				)

				GROUP BY YearMonth, YearQq
				) Cal
				ON CompEx.YearWw = Cal.YearWw
  

