

CREATE PROCEDURE [dbo].[UspGuiFetchCurrentReconMonth]
AS 


SELECT TOP 1 EsdReconMonthName
FROM(
				SELECT TOP( 12) EsdReconMonthName,EsdReconMonthId FROM [fmvbnzsqlprod07].MpsRecon.esd.EsdReconMonths 
				WHERE EsdReconMonthId > (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())-1)
				AND EsdReconMonthId <= (SELECT [dbo].[fnGetMonthIdByDate] (GETDATE())+1)
				order by EsdReconMonthId DESC) T1
ORDER BY EsdReconMonthId ASC



