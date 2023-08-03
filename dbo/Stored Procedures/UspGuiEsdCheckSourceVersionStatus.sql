



CREATE PROC [dbo].[UspGuiEsdCheckSourceVersionStatus] @Bypass INT = 0

AS

/*
		EXEC gui.UspCheckSourceVersionStatus 0
		2021-09-20 - Ben Sala - Switched everything to use replication servers intead of prod. 
*/


IF OBJECT_ID('tempdb..#tmpEsdVersions') IS NOT NULL DROP TABLE #tmpEsdVersions
CREATE TABLE #tmpEsdVersions(SourceApplicationId INT, SourceVersionId INT,[VersionDescription] VARCHAR(100))

	IF @Bypass = 0 BEGIN
		
			INSERT INTO  #tmpEsdVersions
			SELECT 1 AS SourceApplicationId
				,[VersionId] as SourceVersionId
				,[Description]
			  FROM [fabmpsrepldata].SDA_Reporting.dbo.t_sda_version tsv

			  Where [ActiveFlag] = 1 
				AND [Is/Was] = 1
				AND [SDA/OFG] = 1  --###Temporarily DISABLING THIS LINE FOR RAJBIR 4_20_21 - Jeremy
				--AND NOT EXISTS(SELECT 1 FROM [esd].[EsdSourceVersions] T1 WHERE T1.EsdVersionId = @EsdVersionId AND SourceApplicationId = 1 AND T1.SourceVersionId = SourceVersionId)


			---INSERT Version ID's for ISMPS
			INSERT INTO  #tmpEsdVersions
			SELECT  2 as SourceApplicationId
					,[VersionId] as SourceVersionId
					,[Description]
			FROM [ISMPSREPLDATA].[ISMPS_Reporting].[dbo].[t_ismps_version] 

			WHERE [ActiveFlag] = 2
				AND [Is/Was] = 1
				--AND [SDA/OFG] = 1
				--AND NOT EXISTS(SELECT 1 FROM [esd].[EsdSourceVersions] T1 WHERE T1.EsdVersionId = @EsdVersionId AND SourceApplicationId = 2 AND T1.SourceVersionId = SourceVersionId)


			---INSERT Version ID For OneMps
			INSERT INTO  #tmpEsdVersions
			SELECT  5 as SourceApplicationId
					,[VersionId] as SourceVersionId
					,[Description]
			FROM [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_sda_version] -- Replication
			WHERE [ActiveFlag] = 3
				AND [Is/Was] = 1
				AND [SDA/OFG] = 1
				--AND NOT EXISTS(SELECT 1 FROM [esd].[EsdSourceVersions] T1 WHERE T1.EsdVersionId = @EsdVersionId AND SourceApplicationId = 5 AND T1.SourceVersionId = SourceVersionId)

	---INSERT Version ID For OneMps
			INSERT INTO  #tmpEsdVersions
			SELECT  12 as SourceApplicationId
					,1 as SourceVersionId
					,'T'
	

	END

		IF @Bypass = 1 BEGIN
		
			INSERT INTO  #tmpEsdVersions
			SELECT  SourceApplicationId
				,SourceVersionId
				,Division AS SourceVersionName
			  FROM dbo.EsdVersionsBypass  --  Production

		END



IF OBJECT_ID('tempdb..#tmpEsdVersionWithAppNames') IS NOT NULL DROP TABLE #tmpEsdVersionWithAppNames
CREATE TABLE #tmpEsdVersionWithAppNames(SourceApplicationName VARCHAR(100), SourceVersionId INT,VersionDescription VARCHAR(100))

INSERT INTO #tmpEsdVersionWithAppNames
SELECT SA.SourceApplicationName,V.SourceVersionId,V.VersionDescription
FROM   #tmpEsdVersions V
JOIN [dbo].[EtlSourceApplications] SA
	ON V.SourceApplicationId = SA.SourceApplicationId


IF OBJECT_ID('tempdb..#tmpExpectedVersions') IS NOT NULL DROP TABLE #tmpExpectedVersions
CREATE TABLE #tmpExpectedVersions(SourceApplicationName VARCHAR(100),Division VARCHAR(100), SourceVersionId INT)

INSERT INTO #tmpExpectedVersions (SourceApplicationName,Division)
SELECT 'FabMps',''
UNION
SELECT 'Compass',''
UNION
--SELECT 'FabMps', 'IOT'
--UNION
SELECT 'IsMps',''
UNION 
SELECT 'OneMps',''

SELECT 
	T1.SourceApplicationName,
	T1.Division,
--	COALESCE(CAST(T2.SourceVersionId AS VARCHAR(40)),'MISSING') AS SourceVersionId
	 COALESCE(CAST(T2.SourceVersionId AS VARCHAR(40)),'MISSING') AS SourceVersionId
FROM #tmpExpectedVersions T1
LEFT OUTER JOIN
#tmpEsdVersionWithAppNames T2
	ON T1.SourceApplicationName = T2.SourceApplicationName





