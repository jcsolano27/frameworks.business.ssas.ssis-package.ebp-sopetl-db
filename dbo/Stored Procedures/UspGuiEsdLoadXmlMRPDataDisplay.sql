CREATE   PROC [dbo].[UspGuiEsdLoadXmlMRPDataDisplay] (@xmlString TEXT,@LoadedByTool varchar(25))
AS
/****************************************************************************************
DESCRIPTION: This proc loads ESD Source Version Bypass Data to the Recon Database
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [dbo].[UspGuiEsdLoadXmlMRPDataDisplay]	 @xmlString = '<list><record EsdVersionId=115 IsMRP=True/></list>' @LoadedByTool='ESD_UI'
-- TEST HARNESS */
 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER


--DECLARE @xmlString varchar(max) = '<list><record><EsdVersionId>172</EsdVersionId><Versions>FabMps:16218 IsMps:17933 OneMps:1622 Compass:1</Versions><IsMrp>False</IsMrp></record>></list>'
--DECLARE @LoadedByTool varchar(255) = 'Excel Workbook'

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString



		IF OBJECT_ID('tempdb..#TmpMPRShow') IS NOT NULL drop table #TmpMPRShow
		CREATE TABLE #TmpMPRShow(
			EsdVersionId INT,
			RestrictHorizonInd BIT
		) 

		INSERT INTO #TmpMPRShow(
			EsdVersionId,
			RestrictHorizonInd
		)
	SELECT  EsdVersionId ,
			RestrictHorizonInd

		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
					EsdVersionId INT,
					RestrictHorizonInd BIT
			   ) T1

		--	   select * from #TmpMPRShow
EXEC sp_xml_removedocument @idoc


		--UPDATE Rows that have already been eltered but the Quantity has changed
		UPDATE T1 
			SET T1.RestrictHorizonInd = T2.RestrictHorizonInd
		FROM [dbo].[EsdVersions] T1
		JOIN #TmpMPRShow T2
			ON T2.EsdVersionId = T1.EsdVersionId

		UPDATE T1A 
			SET T1A.RestrictHorizonInd = T2.RestrictHorizonInd
		FROM dbo.SvdSourceVersion T1A
		JOIN #TmpMPRShow T2
		ON T2.EsdVersionId = T1A.SourceVersionId
		AND T1A.SvdSourceApplicationId = 2
	--		WHERE T2.IsMrp <> IsNull(T1.IsMrp,0)
		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
		--	UPDATE T1A 
		--	SET T1A.IsMrp = T2.IsMrp
		--FROM dbo.SvdSourceVersion T1A
		--JOIN #TmpMPRShow T2
		--	ON T2.EsdVersionId = T1A.SourceVersionId
		--	AND T1A.SvdSourceApplicationId = 2


END