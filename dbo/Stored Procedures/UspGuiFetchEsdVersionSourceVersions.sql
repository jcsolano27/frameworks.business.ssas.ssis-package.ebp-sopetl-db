
/****** 

EXEC [dbo].[UspGuiFetchEsdVersionSourceVersions] @EsdVersionId = 151
SELECT * FROM   [dbo].[GuiUIEsdVersion]


 ******/


CREATE PROC [dbo].[UspGuiFetchEsdVersionSourceVersions] (@EsdVersionId int)

AS
-- Insert Selected ESD Version into Database
DELETE  FROM [dbo].[GuiUIEsdVersion]
INSERT INTO [dbo].[GuiUIEsdVersion]
SELECT  @EsdVersionId 

SELECT 
	  SA.SourceApplicationName
	  ,ESV.SourceVersionId
  FROM dbo.[EsdBaseVersions] BV
  JOIN [dbo].[PlanningMonths] RM
	ON RM.[PlanningMonthId] = BV.[PlanningMonthId]
  JOIN dbo.EsdVersions EV
	ON EV.EsdBaseVersionId = BV.EsdBaseVersionId
  LEFT JOIN dbo.EsdSourceVersions ESV
	ON EV.EsdVersionId = ESV.EsdVersionId

	LEFT JOIN [dbo].[EtlSourceApplications] SA
		ON ESV.SourceApplicationId = SA.SourceApplicationId
	WHERE EV.EsdVersionId= @EsdVersionId

--GO




