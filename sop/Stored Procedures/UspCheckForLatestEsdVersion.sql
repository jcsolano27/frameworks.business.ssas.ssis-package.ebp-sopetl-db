CREATE   PROC [sop].[UspCheckForLatestEsdVersion]
AS

----**********************************************************************************************************************************************************
     
----    Purpose:   This procedure checks two things: 
----               1) If an older ESD POR Version was published again 
----               2) If a new ESD POR Version was published
----               In both cases, the procedure updates the sop.PlanVersion table and calls the UspQueueTableLoadGroup 
----               procedure to update the table versions that depend on this trigger for generation.
--------    2023-07-28  fjunio2x        Check if the version is Uncontrained based on EsdVersionName

----    Called by: Job ebpcdsopesdver
----
----    Date        User            Description
----**********************************************************************************************************************************************************
----    2023-07-07	psillosx        Initial Release
----    2023-07-21  fjunio2x        Rebuilt procedure logic to handle publications of old ESD versions.
----    2023-07-27  fjunio2x        Inclued logic to check if an EsdVersion was IsPOR unflaged.
----    2023-07-31  fjunio2x        Check if the version is Uncontrained based on EsdVersionName
----    2023-08-01  fjunio2x        Calling [sop].[UspQueueTableLoadGroup] with different groups
----    2023-08-02  fjunio2x        When IsPOR is unflaged, call the procedure [sop].[UspLoadPlanVersion] to update sop.PlanVersion
----**********************************************************************************************************************************************************

BEGIN
	SET NOCOUNT ON

	---------------------------------------------------------------------------------------------------------------------------------------
	-- Check if an EsdVersion was IsPOR flaged.                                                                                          --
	---------------------------------------------------------------------------------------------------------------------------------------
	DECLARE cEsdVersion CURSOR 
	FOR
	SELECT EsdVersionId
	     , EsdVersionName
		 , IsPOR
		 , ISNULL(PublishedOn,CreatedOn) EsdVersionDate
	FROM   [dbo].[EsdVersions]
	WHERE  (IsPOR = 1 Or IsPrePORExt = 1 Or EsdVersionName like '%UNCONSTRAINED%')
	  And  (IsNull(PublishedOn,CreatedOn) > GetDate()-120)

	DECLARE @SourceVersionId INT;
	DECLARE @EsdVersionId    INT;
	DECLARE @EsdVersionName  VARCHAR(50);
	DECLARE @EsdVersionDate  DATETIME;
	DECLARE @ModifiedOnDtm   DATETIME;
	DECLARE @IsPOR           INT;
	DECLARE @ActiveInd       INT;

	Open cEsdVersion;
	FETCH NEXT FROM cEsdVersion INTO @EsdVersionId, @EsdVersionName, @IsPOR, @EsdVersionDate
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @ModifiedOnDtm = MAX(ModifiedOnDtm)
		FROM   sop.PlanVersion 
		Where  SourceSystemId  = sop.CONST_SourceSystemId_Esd()
		  AND  SourceVersionId = @EsdversionId;

		SELECT @ActiveInd = ActiveInd
		FROM   sop.PlanVersion 
		Where  SourceSystemId  = sop.CONST_SourceSystemId_Esd()
		  AND  SourceVersionId = @EsdversionId
		  AND  ModifiedOnDtm   = @ModifiedOnDtm;

		IF @EsdVersionDate > @ModifiedOnDtm -- If the date of an old version changed
		OR @ModifiedOnDtm Is Null           -- If it´s a new ESD Version 
		OR (@IsPOR = 1 And @ActiveInd = 0)  -- If the version was flagged to IsPOR again
		BEGIN
			-- Call the procedure that manage sop.PlanVersion
			EXEC [sop].[UspLoadPlanVersion] @Operation = 'I', @EsdVersionId = @EsdVersionId

            IF @EsdVersionName LIKE '%UNCONSTRAINED%'
		        -- UNCONSTRAINED - Call the procedure that generates sop.BatchRun for GROUP 4	
				BEGIN
					EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '1'
					EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '4', @EsdVersionId = @EsdversionId
					EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '17'
				END
			ELSE
				-- CONSTRAINED - Call the procedure that generates sop.BatchRun for GROUP 5
				BEGIN
					EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '1'
					EXEC [sop].[UspQueueTableLoadGroup] @TableLoadGroupIdList = '5', @EsdVersionId = @EsdversionId
				END
		END

		FETCH NEXT FROM cEsdVersion INTO @EsdVersionId, @EsdVersionName, @IsPOR, @EsdVersionDate

	END
	CLOSE cEsdVersion
	DEALLOCATE cEsdVersion


	---------------------------------------------------------------------------------------------------------------------------------------
	-- Check if an EsdVersion was IsPOR unflaged                                                                                         --
	---------------------------------------------------------------------------------------------------------------------------------------
	DECLARE cPlanVersion CURSOR 
	FOR
	SELECT Distinct SourceVersionId
	FROM   [sop].[PlanVersion]
	WHERE  SourceSystemId        = sop.CONST_SourceSystemId_Esd()
	  AND  ConstraintCategoryId <> sop.CONST_ConstraintCategoryId_Unconstrained()

	Open cPlanVersion;
	FETCH NEXT FROM cPlanVersion INTO @SourceVersionId
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @EsdVersionId = MAX(EsdVersionId)
		FROM   dbo.EsdVersions
		WHERE  EsdVersionId = @SourceVersionId
		  AND  IsPOR        = 1;

		IF @EsdVersionId Is Null  
			-- Call the procedure that manage sop.PlanVersion
			EXEC [sop].[UspLoadPlanVersion] @Operation = 'D', @EsdVersionId = @SourceVersionId

		FETCH NEXT FROM cPlanVersion INTO @SourceVersionId
	END
	CLOSE cPlanVersion
	DEALLOCATE cPlanVersion

END