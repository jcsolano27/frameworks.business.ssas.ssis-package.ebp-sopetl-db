




CREATE PROC [dbo].[UspGuiEsdLoadXmlSourceVersionUpdate] (@xmlString TEXT,@LoadedByTool varchar(25), @EsdVersionId INT) 
AS
/****************************************************************************************
DESCRIPTION: This proc loads ESD Source Version Bypass Data to the Recon Database
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [esd].[UspLoadXmlSourceVersionBypass]	 @xmlString : <list><record><SourceApplicationName>Compass</SourceApplicationName><Division /><SourceVersionId>4</SourceVersionId><SourceVersionId1>1</SourceVersionId1></record><record><SourceApplicationName>FabMps</SourceApplicationName><Division /><SourceVersionId>5</SourceVersionId><SourceVersionId1>2</SourceVersionId1></record><record><SourceApplicationName>IsMps</SourceApplicationName><Division /><SourceVersionId>6</SourceVersionId><SourceVersionId1>3</SourceVersionId1></record><record><SourceApplicationName>OneMps</SourceApplicationName><Division /><SourceVersionId>7</SourceVersionId><SourceVersionId1>4</SourceVersionId1></record></list>
@LoadedByTool : Excel Workbook

-- TEST HARNESS */
 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)

--DECLARE @xmlString varchar(max) =  '<list><record><SourceApplicationName>Compass</SourceApplicationName><Division /><SourceVersionId>4</SourceVersionId><SourceVersionId1>1</SourceVersionId1></record><record><SourceApplicationName>FabMps</SourceApplicationName><Division /><SourceVersionId>5</SourceVersionId><SourceVersionId1>2</SourceVersionId1></record><record><SourceApplicationName>IsMps</SourceApplicationName><Division /><SourceVersionId>6</SourceVersionId><SourceVersionId1>3</SourceVersionId1></record><record><SourceApplicationName>OneMps</SourceApplicationName><Division /><SourceVersionId>7</SourceVersionId><SourceVersionId1>4</SourceVersionId1></record></list>'
--DECLARE @LoadedByTool varchar(250) =  'Excel Workbook'
--DECLARE @EsdVersionId int	= 115	
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

		--UPDATE Rows that have already been eltered but the Quantity has changed
		UPDATE T1 
			SET T1.SourceVersionId = T2.SourceVersionId

		FROM dbo.EsdSourceVersions T1
		JOIN (
		select * from  #TmpSourceVersionBypass T2
			JOIN dbo.EtlSourceApplications SA
					ON T2.SourceApplication = SA.SourceApplicationName
					) T2
			ON T2.SourceApplicationID = T1.SourceApplicationID
		WHERE T1.EsdVersionId = @EsdVersionId
		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
END	

