



CREATE PROC [dbo].[UspGuiEsdFetchSourceVersions] @Bypass INT = 0
AS
	---Return Version ID's for FabMPS, IsMPS, OneMPS 
	DECLARE @SourceVersions TABLE (SourceApplicationId INT NOT NULL, SourceVersionId INT NULL);
	/*
		[esd].[UspEsdFetchSourceVersions] 0
		2021-09-20 - Ben Sala - Switched everything to use replication servers intead of prod. 
	*/

	IF @Bypass = 0 
		BEGIN
			INSERT INTO @SourceVersions
			SELECT 1 AS SourceApplicationId
				,[VersionId] as SourceVersionId
			  FROM [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_sda_version]  --  Production

			  Where [ActiveFlag] = 1 
				AND [Is/Was] = 1

			UNION
			---INSERT Version ID's for ISMPS
			SELECT  2 as SourceApplicationId
					,[VersionId] as SourceVersionId
			FROM [ISMPSREPLDATA].[ISMPS_Reporting].[dbo].[t_ismps_version] 
			WHERE [ActiveFlag] = 2
				AND [Is/Was] = 1
				
			UNION
			---INSERT Version ID For OneMps
			SELECT  5 as SourceApplicationId
					,[VersionId] as SourceVersionId
			 FROM [FABMPSREPLDATA].[SDA_Reporting].[dbo].[t_sda_version]  --  Production
			WHERE [ActiveFlag] = 3
				AND [Is/Was] = 1

			Union
			Select 12,1
		END
	ELSE IF @Bypass = 1
		BEGIN
			INSERT INTO  @SourceVersions
			SELECT  SourceApplicationId
				,SourceVersionId
			FROM dbo.EsdVersionsBypass
			
			ORDER BY 1,2
		END

	SELECT * FROM @SourceVersions
--	WHERE SourceVersionId <> '1'




