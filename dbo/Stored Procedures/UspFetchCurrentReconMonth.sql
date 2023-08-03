

CREATE PROCEDURE [dbo].[UspFetchCurrentReconMonth]
AS 


SELECT TOP 1 EsdReconMonthName
FROM(
				SELECT TOP( 12) EsdReconMonthName,EsdReconMonthId FROM [fmvbnzsqlprod07].MpsRecon.esd.EsdReconMonths 
		--		WHERE EsdReconMonthId > (SELECT [fmvbnzsqlprod07].MpsRecon.[dbo].[fnGetMonthIdByDate] (GETDATE())-1)
		--		AND EsdReconMonthId <= (SELECT [fmvbnzsqlprod07].MpsRecon.[dbo].[fnGetMonthIdByDate] (GETDATE())+1)
				order by EsdReconMonthId DESC) T1
ORDER BY EsdReconMonthId ASC



