



CREATE PROC dbo.[UspGuiEsdLoadXmlSourceVersionBypass] (@xmlString TEXT,@LoadedByTool varchar(25))
AS
/****************************************************************************************
DESCRIPTION: This proc loads ESD Source Version Bypass Data to the Recon Database
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [esd].[UspLoadXmlSourceVersionBypass]	 @xmlString = '<list><record SourceApplication="FabMps" Division="CS" SourceVersionId="11111"/></list>' @LoadedByTool='ESD_UI'
-- TEST HARNESS */
 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString


		IF OBJECT_ID('tempdb..#TmpSourceVersionBypass') IS NOT NULL drop table #TmpSourceVersionBypass
		CREATE TABLE #TmpSourceVersionBypass(
			SourceApplication VARCHAR(50),
			Division VARCHAR(25),
			SourceVersionId INT
		) 

		INSERT INTO #TmpSourceVersionBypass(
			SourceApplication,
			Division,
			SourceVersionId
		)
	SELECT  SourceApplicationName AS SourceApplication,
			Division,
			SourceVersionId

		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
					SourceApplicationName VARCHAR(50),
					Division VARCHAR(25),
					SourceVersionId int
			   ) T1

EXEC sp_xml_removedocument @idoc
		--DELETE Rows where an Adjustment has been made, but then deleted
		DELETE  T1
		FROM dbo.EsdVersionsBypass T1
		JOIN #TmpSourceVersionBypass T2
			ON T2.SourceApplication = T1.SourceApplication

		--UPDATE Rows that have already been eltered but the Quantity has changed
		UPDATE T1 
			SET T1.SourceVersionId = T2.SourceVersionId
		FROM dbo.EsdVersionsBypass T1
		JOIN #TmpSourceVersionBypass T2
			ON T2.SourceApplication = T1.SourceApplication
			AND T2.Division = T1.Division
		WHERE T2.SourceVersionId IS NOT NULL
		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
		INSERT INTO dbo.EsdVersionsBypass
				   (
						SourceApplicationId,
						SourceApplication,
						Division,
						SourceVersionId
				   )

				SELECT SA.SourceApplicationId
					   ,T1.SourceApplication
					  ,Division
					  ,SourceVersionId
				FROM #TmpSourceVersionBypass T1
				JOIN dbo.EtlSourceApplications SA
					ON T1.SourceApplication = SA.SourceApplicationName
				WHERE NOT EXISTS (SELECT 1 FROM  dbo.EsdVersionsBypass T2 
									WHERE T2.SourceApplication = T1.SourceApplication 
									AND T2.Division = T1.Division
									AND T2.SourceVersionId = T1.SourceVersionId
									)
						AND T1.SourceVersionId IS NOT NULL
END

