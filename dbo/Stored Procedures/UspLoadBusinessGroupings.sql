CREATE PROC [dbo].[UspLoadBusinessGroupings]

AS

----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from Hana for Business Grouping table   
----                        Source:      [dbo].[StgFinancePorBullBearForecast]
----                        Destination: [dbo].[BusinessGrouping]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters		None
   
----    Date        User            Description
----***************************************************************************-
----    2022-08-29  atairumx        Initial Release
----	2022-10-11	atairumx		Adjustments to Hana's view
----	2022-12-16	atairumx		Adjustment to remove records NULL to SnOPComputeArchitectureNm AND SnOPProcessNodeNm before to MERGE in [dbo].[BusinessGrouping]

----*********************************************************************************/

BEGIN
	SET NOCOUNT ON

/*
EXEC [dbo].[UspLoadBusinessGroupings]
*/

begin try 

	DECLARE	@LastModifiedDate DATETIME = (SELECT MAX(ModifiedOn) FROM [dbo].[StgFinancePorBullBearForecast])
	DECLARE @ProfiseeBusinessGroupings TABLE (SnOPComputeArchitectureNm VARCHAR(100), SnOPProcessNodeNm VARCHAR(100))
	DECLARE @NewBusinessGroupings TABLE (SnOPComputeArchitectureNm VARCHAR(100), SnOPProcessNodeNm VARCHAR(100))

	INSERT INTO @ProfiseeBusinessGroupings
	SELECT DISTINCT SnOPComputeArchitectureNm, SnOPProcessNodeNm FROM [dbo].[StgFinancePorBullBearForecast]
	WHERE ModifiedOn = @LastModifiedDate
		AND SnOPComputeArchitectureNm IS NOT NULL 
		AND SnOPProcessNodeNm IS NOT NULL

	INSERT INTO @NewBusinessGroupings
	SELECT * FROM @ProfiseeBusinessGroupings
	EXCEPT
	SELECT DISTINCT SnOPComputeArchitectureNm, SnOPProcessNodeNm FROM [dbo].[BusinessGrouping]

	--INSERT INTO [dbo].[BusinessGrouping] (SnOPComputeArchitectureNm, SnOPProcessNodeNm)
	--SELECT 
	--	SnOPComputeArchitectureNm
	--,	SnOPProcessNodeNm
	--FROM @NewBusinessGroupings

					MERGE
					[dbo].[BusinessGrouping] AS BG
				USING 
					@NewBusinessGroupings AS NBG 
						ON (BG.SnOPComputeArchitectureNm = NBG.SnOPComputeArchitectureNm
							AND
							BG.SnOPProcessNodeNm = NBG.SnOPProcessNodeNm)
				WHEN NOT MATCHED BY TARGET
					THEN
						INSERT
						VALUES (NBG.SnOPComputeArchitectureNm, NBG.SnOPProcessNodeNm, getdate(), original_login());
			


------> Insert log as success in log table 

    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = 'SVD'
      , @Message = 'Load data to BusinessGrouping'
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
      , @Message = 'Load data to BusinessGrouping'
      , @Status = 'ERROR'
      , @Exception = NULL
      , @BatchId = NULL;

end catch


	SET NOCOUNT OFF
END
