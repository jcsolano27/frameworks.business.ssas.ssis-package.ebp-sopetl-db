


CREATE PROC [dbo].[UspLoadSvdSourceVersion]

AS
/************************************************************************************
DESCRIPTION: This proc is used to load data from DB versions to SvdSourceVersion (WIP)
*************************************************************************************/

BEGIN
	SET NOCOUNT ON

/*
EXEC [dbo].[UspLoadSvdSourceVersion]
*/

/**************************Change Log**************************************************/
/*Date----------User--------------Description-------------------------------------------------------------------------------------------------------------------------------*/
/*2022-11-22----henrykx.manente---Add IsMrp flag to SvdSourceVersion table--------------------------------------------------------------------------------------------------*/
/*2023-05-22----rmiralhx----------Added logic to remove SourceVersionIds not flagged as IsPOR, IsPrePORExt, RetainFlag, IsPrePOR and not present in dbo.SvdOutput-----------*/                                
/**************************************************************************************/


/*************************************************************************
/******** WAITING APPLICATION ID TO BE CREATED IN FINAL SOS TABLE ********/
/*********** THIS IS A TEMPORARY SOLUTION FOR SAMPLE DATA ONLY ***********/
**************************************************************************/

------> Create Variables

BEGIN TRY 

	DECLARE	@CONST_SvdSourceApplicationId_Esd						INT = [dbo].[CONST_SvdSourceApplicationId_Esd]()
			,@CONST_SvdSourceApplicationId_NotApplicable			INT = [dbo].[CONST_SvdSourceApplicationId_NotApplicable]()
			,@CONST_SvdSourceApplicationId_HDMR						INT = [dbo].[CONST_SvdSourceApplicationId_HDMR]()
			,@CONST_SvdSourceApplicationId_NonHdmr					INT = [dbo].[CONST_SvdSourceApplicationId_NonHdmr]()
			,@CONST_ParameterId_TargetSupply						INT = [dbo].[CONST_ParameterId_TargetSupply]()
	
	DECLARE @IncludeSVD table (PlanningMonth int )	;		

	DECLARE @NonHdmrTemp TABLE (
		Id				INT
	,	PlanningMonth	INT
	,	SourceVersionNm	VARCHAR(30)
	);

	DECLARE @SvdSourceVersion TABLE
		(
		[PlanningMonth] int,
		[SvdSourceApplicationId] int,
		[SourceVersionId] int,
		[SourceVersionNm] varchar(1000),
		[SourceVersionType] varchar(100),
		[RestrictHorizonInd] bit
		);

	with POR as 
		(
			Select distinct Planningmonth from dbo.financepor
			except
			select distinct PlanningMonth from dbo.SvdSourceVersion
			where SourceVersionId = 0 and SvdSourceApplicationId = 0
		),
	BullBear as 
	(
	Select distinct PlanningMonth from dbo.FinancePorBullBearForecast
	except
	select distinct PlanningMonth from dbo.SvdSourceVersion
	where SourceVersionId = 0 and SvdSourceApplicationId = 0
	),
	ConsensusDemand as 
	(
	Select distinct SnOPDemandForecastMonth from dbo.[SnOPDemandForecast]
	except
	select distinct PlanningMonth from dbo.SvdSourceVersion
	where SourceVersionId = 0 and SvdSourceApplicationId = 0
	),
	CustomerRequest as
	(
	Select distinct PlanningMonth from dbo.[CustomerRequest]
	except
	select distinct PlanningMonth from dbo.SvdSourceVersion
	where SourceVersionId = 0 and SvdSourceApplicationId = 0
	),
	AllocationBacklog as
	(
	Select distinct PlanningMonth from dbo.[AllocationBacklog]
	except
	select distinct PlanningMonth from dbo.SvdSourceVersion
	where SourceVersionId = 0 and SvdSourceApplicationId = 0
	)
	
	INSERT INTO @IncludeSvd
	select * from POR
	Union
	select * from bullbear
	Union
	select * from ConsensusDemand
	Union
	select * from CustomerRequest
	Union
	select * from AllocationBacklog

	--Select * from @IncludeSvd order by 1 asc
	
	-- Insert all PlanningMonths from other sources that don't have data from [SvdSourceApplicationId],[SourceVersionId],[SourceVersionNm]

	INSERT INTO @SvdSourceVersion
	SELECT 
	PlanningMonth
	, @CONST_SvdSourceApplicationId_NotApplicable AS [SvdSourceApplicationId]
	, 0
	, 'Not Applicable'
	, 'N/A'
	, 0 AS RestrictHorizonInd
	from @IncludeSvd

	-- Insert data from ESD
	
	--	DECLARE	@CONST_SvdSourceApplicationId_Esd						INT = [dbo].[CONST_SvdSourceApplicationId_Esd]()

	INSERT INTO @SvdSourceVersion
	SELECT DISTINCT
		epn.planningmonth as [PlanningMonth]	
	,   @CONST_SvdSourceApplicationId_Esd AS [SvdSourceApplicationId]
	,	EsdVersionId [SourceVersionId]
	,	EsdVersionName [SourceVersionNm]
	,	CASE 
			WHEN RTRIM(EsdVersionName) LIKE '%Die Feasible%' THEN 'Die Feasible'
			WHEN RTRIM(EsdVersionName) LIKE '%Substrate Feasible%' THEN 'Substrate Feasible'
			ELSE 'Other'
		END [SourceVersionType]
	, ev.RestrictHorizonInd
	FROM [dbo].[EsdVersions] ev
		INNER JOIN [dbo].[EsdBaseVersions] ebv
			on ev.EsdBaseVersionId = ebv.EsdBaseVersionId
		INNER JOIN [dbo].[PlanningMonths] epn
			on ebv.PlanningMonthId = epn.PlanningMonthId
	WHERE IsPor = 1 OR IsPrePorExt = 1
	--EXCEPT
	--SELECT [PlanningMonth],[SvdSourceApplicationId],[SourceVersionId],[SourceVersionNm],[SourceVersionType]
	--FROM  @SvdSourceVersion


	-- Insert data from HDMR
	
	--	DECLARE	@CONST_SvdSourceApplicationId_HDMR						INT = [dbo].[CONST_SvdSourceApplicationId_HDMR]()

	INSERT INTO @SvdSourceVersion
	SELECT DISTINCT
		sd.PlanningMonth as [PlanningMonth]	
	,	@CONST_SvdSourceApplicationId_HDMR AS [SvdSourceApplicationId]
	,	sd.sourceversionID [SourceVersionId]
	,	hps.SourceVersionNm [SourceVersionNm]
	,	SnapshotType [SourceVersionType]
	,	0 AS RestrictHorizonInd
	FROM [dbo].[SupplyDistribution] SD
		INNER JOIN [dbo].[HdmrSnapshot] hps
			on sd.sourceversionid = hps.[SourceVersionId] AND SD.SupplyParameterId = @CONST_ParameterId_TargetSupply
	--EXCEPT
	--SELECT [PlanningMonth],[SvdSourceApplicationId],[SourceVersionId],[SourceVersionNm],[SourceVersionType]
	--FROM  @SvdSourceVersion

	INSERT INTO @SvdSourceVersion
	SELECT DISTINCT
		sd.PlanningMonth as [PlanningMonth]	
	,	[SvdSourceApplicationId]
	,	sd.sourceversionID [SourceVersionId]
	,	hps.SourceVersionNm [SourceVersionNm]
	,	SnapshotType [SourceVersionType]
	,	0 AS RestrictHorizonInd
	FROM [dbo].[TargetSupply] SD
		INNER JOIN [dbo].[HdmrSnapshot] hps
			on sd.sourceversionid = hps.[SourceVersionId] AND SD.SupplyParameterId = @CONST_ParameterId_TargetSupply
	WHERE [SvdSourceApplicationId] = @CONST_SvdSourceApplicationId_HDMR
	--EXCEPT
	--SELECT [PlanningMonth],[SvdSourceApplicationId],[SourceVersionId],[SourceVersionNm],[SourceVersionType]
	--FROM  @SvdSourceVersion

	-- Insert data from NON HDMR
	
	INSERT INTO @NonHdmrTemp	
		SELECT 
			RANK() OVER (PARTITION BY PlanningMonth ORDER BY SourceVersionNm ASC) Id
		,	UNPVT.PlanningMonth		
		,	UNPVT.SourceVersionNm				
		FROM
			(
				SELECT
					PlanningFiscalYearMonthNbr AS PlanningMonth								
				,	FullBuildTargetQty
				,	DieBuildTargetQty
				,	SubstrateBuildTargetQty
				FROM [dbo].StgNonHdmrProducts NHdmr
			) P
		UNPIVOT
			(Quantity FOR SourceVersionNm IN
				(FullBuildTargetQty,DieBuildTargetQty,SubstrateBuildTargetQty)
			) AS UNPVT
		GROUP BY PlanningMonth, SourceVersionNm
		ORDER BY 1,2

	INSERT INTO @SvdSourceVersion
	SELECT 
		PlanningMonth
	,	@CONST_SvdSourceApplicationId_NonHdmr AS SvdSourceApplicationId
	,	Id				AS SourceVersoinId
	,	SourceVersionNm	AS SourceVersionNm
	,	SourceVersionNm	AS SourceVersionType
	,	0 AS RestrictHorizonInd
	FROM @NonHdmrTemp
	--	EXCEPT
	--SELECT [PlanningMonth],[SvdSourceApplicationId],[SourceVersionId],[SourceVersionNm],[SourceVersionType]
	--FROM  [dbo].[SvdSourceVersion];


			MERGE
				[dbo].[SvdSourceVersion] AS SSV
			USING 
				@SvdSourceVersion AS SSVL 
					ON  (SSV.PlanningMonth = SSVL.PlanningMonth
						 AND
						 SSV.SvdSourceApplicationId = SSVL.SvdSourceApplicationId
						 AND
						 SSV.SourceVersionId = SSVL.SourceVersionId
						 --AND
						 --SSV.SourceVersionNm = SSVL.SourceVersionNm
						 --AND
						 --SSV.SourceVersionType = SSVL.SourceVersionType
						)
			WHEN MATCHED AND (SSV.SourceVersionNm <> SSVL.SourceVersionNm OR SSV.RestrictHorizonInd <> SSVL.RestrictHorizonInd)
					THEN
						UPDATE SET	SSV.SourceVersionNm = SSVL.SourceVersionNm,
									SSV.SourceVersionType = SSVL.SourceVersionType,
									SSV.CreatedOn = GETDATE(),
									SSV.CreatedBy = original_login(),
									SSV.RestrictHorizonInd = SSVL.RestrictHorizonInd
			
			WHEN NOT MATCHED BY TARGET
				THEN
					INSERT
					VALUES (SSVL.PlanningMonth, SSVL.SvdSourceApplicationId, SSVL.SourceVersionId, SSVL.SourceVersionNm, SSVL.SourceVersionType, getdate(), original_login(), SSVL.RestrictHorizonInd);
			--WHEN NOT MATCHED BY SOURCE 
			--	THEN DELETE;
            
	--Remove SourceVersionIds not flagged as IsPOR, IsPrePORExt, IsPrePOR AND RetainFlag from table and not present in dbo.SvdOutput
	DELETE S FROM [dbo].[SvdSourceVersion] S
	INNER JOIN [dbo].[EsdVersions] ev ON S.SourceVersionId = ev.EsdVersionId
	WHERE ev.IsPOR = 0 AND  ev.IsPrePORExt = 0 AND ev.IsPrePOR= 0 AND ev.RetainFlag = 0 
	AND  S.SvdSourceApplicationId = @CONST_SvdSourceApplicationId_Esd
	AND SvdSourceVersionId NOT IN (SELECT DISTINCT SvdSourceVersionId FROM dbo.SvdOutput SO WHERE SO.SvdSourceVersionId = S.SvdSourceVersionId)            

------> Insert log as success in log table
  
    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = 'SVD'
      , @Message = 'Load data to SVDSourceVersion'
      , @Status = 'END'
      , @Exception = NULL
      , @BatchId = NULL;

end try

begin catch

------> Insert log as error in log table

    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Error'
      , @Category = 'Etl'
      , @SubCategory = 'SVD'
      , @Message = 'Load data to SVDSourceVersion'
      , @Status = 'ERROR'
      , @Exception = NULL
      , @BatchId = NULL;

end catch

	SET NOCOUNT OFF

END