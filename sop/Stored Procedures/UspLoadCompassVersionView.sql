----/********************************************************************************    
----    
----    Purpose:        This proc is used to load [sop].[CompassVersionView] data    
----                    Source:      [sop].[StgCompassVersionView]
----                    Destination: [sop].[CompassVersionView]
----    Called by:      SSIS    
----    
----    Result sets:    None    
----    
----    Date		User            Description    
----*********************************************************************************    
----	2023-07-25  hmanentx		Initial Release
----*********************************************************************************/    

CREATE   PROC [sop].[UspLoadCompassVersionView]
WITH EXEC AS OWNER
AS BEGIN

	SET NOCOUNT ON;

	MERGE sop.CompassVersionView T
	USING
	(
		SELECT
			VersionId
			,PublishLogId
			,LrpCycleYearNbr
			,LrpCycleQuarterNbr
			,ScenarioId
			,ProfileId
			,ScenarioNm
			,ProfileDsc
			,VersionDsc
			,IsPorCd
			,PublishStatusCd
			,StartTs
			,EndTs
			,LoadedToHanaTs
		FROM sop.StgCompassVersionView
	) S
	ON
		S.VersionId = T.VersionId
		AND S.PublishLogId = T.PublishLogId
	WHEN NOT MATCHED BY TARGET THEN
		INSERT
		(
			VersionId
			,PublishLogId
			,LrpCycleYearNbr
			,LrpCycleQuarterNbr
			,ScenarioId
			,ProfileId
			,ScenarioNm
			,ProfileDsc
			,VersionDsc
			,IsPorCd
			,PublishStatusCd
			,StartTs
			,EndTs
			,LoadedToHanaTs
			,CreatedOn
			,CreatedBy
		)
		VALUES
		(
			VersionId
			,PublishLogId
			,LrpCycleYearNbr
			,LrpCycleQuarterNbr
			,ScenarioId
			,ProfileId
			,ScenarioNm
			,ProfileDsc
			,VersionDsc
			,IsPorCd
			,PublishStatusCd
			,StartTs
			,EndTs
			,LoadedToHanaTs
			,GETDATE()
			,ORIGINAL_LOGIN()
		)
	WHEN MATCHED THEN
		UPDATE SET
			T.LrpCycleYearNbr = S.LrpCycleYearNbr,
			T.LrpCycleQuarterNbr = S.LrpCycleQuarterNbr,
			T.ScenarioId = S.ScenarioId,
			T.ProfileId = S.ProfileId,
			T.ScenarioNm = S.ScenarioNm,
			T.ProfileDsc = S.ProfileDsc,
			T.VersionDsc = S.VersionDsc,
			T.IsPorCd = S.IsPorCd,
			T.PublishStatusCd = S.PublishStatusCd,
			T.StartTs = S.StartTs,
			T.EndTs = S.EndTs,
			T.LoadedToHanaTs = S.LoadedToHanaTs,
			T.ModifiedOn = GETDATE(),
			T.ModifiedBy = ORIGINAL_LOGIN();

	SET NOCOUNT OFF;

END