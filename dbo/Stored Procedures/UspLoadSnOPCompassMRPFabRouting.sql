
CREATE   PROCEDURE [dbo].[UspLoadSnOPCompassMRPFabRouting]
    @Debug TINYINT = 0
  , @BatchId VARCHAR(100) = NULL
  , @BatchRunId INT = -1
  , @ParameterList VARCHAR(1000) = ''

AS
----/*********************************************************************************
     
----    Purpose:        Processes data   
----                        Source:      [dbo].[StgSnOPCompassMRPFabRouting]
----                        Destination: [dbo].[SnOPCompassMRPFabRouting]

----    Called by:      SSIS
         
----    Result sets:    None
     
----    Parameters:
----                    @Debug:
----                        1 - Will output some basic info with timestamps
----                        2 - Will output everything from 1, as well as rowcounts
         
----    Return Codes:   0   = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-01-31  hmanentx        Initial Release
----    2023-04-06  rmiralhx        Remove columns DonorFlag and RecipientFlag
----    2023-04-12  rmiralhx        Add logic to reaise error in case of duplicates and load historical data
----*********************************************************************************/

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

BEGIN TRY

    -- Error and transaction handling setup ********************************************************
    DECLARE
        @ReturnErrorMessage VARCHAR(MAX)
      , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
      , @CurrentAction      VARCHAR(4000)
      , @DT                 VARCHAR(50)  = SYSDATETIME()
      , @Message            VARCHAR(MAX);

    SELECT @CurrentAction = @ErrorLoggedBy + ': SP Starting';

    IF (@BatchId IS NULL)
        SELECT @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN();

    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'BEGIN'
      , @Exception = NULL
      , @BatchId = @BatchId;

	-- Main Logic

		-- Merge Entries to the Main Table
		-- FOR NOW, USING DELETE/INSERT LOGIC UNTIL WE HAVE A CLEAR KEY FOR THE TABLE
		DROP TABLE IF EXISTS #TBL_PublishLogId

		SELECT PublishLogId
		INTO #TBL_PublishLogId
		FROM [dbo].[StgSnOPCompassMRPFabRouting] S
		GROUP BY PublishLogId

		-- IF THE PublishLogId ALREADY EXISTS IN THE TABLE, WE DON`T LOAD IT (AS DEFINED BY SUDHA)
		DELETE FROM C
		FROM #TBL_PublishLogId S
		INNER JOIN [dbo].[SnOPCompassMRPFabRouting] C ON S.PublishLogId = C.PublishLogId

		/*
			2023-01-27
			AFTER TALKING TO JOHN, THE DEFINITION IS THAT WE WILL HAVE IN THE MAIN TABLE JUST THE DATA FROM OLD PUBLISHES
			THAT WERE UPDATED IN POWERON. WHEN WE LOAD A NEW PUBLISH, ALL THE DATA FROM THE OLD ONES THAT WEREN`T UPDATED
			WOULD BE DELETED AND THE NEW PUBLISH WILL BE LOADED.
		*/
        
        --HISTORICAL LOAD
        --Load records that have NOT been overwritten to the historical table 
        --First, it checks if exists any duplicates in the SnOPCompassMRPFabRouting, if exist, an error is shown and it aborts else process is continued 
        DROP TABLE IF EXISTS #TmpStgSnOPCompassMRPFabRouting;
        
        DECLARE @verifyDup INT = 0;
        
        SET @verifyDup = 
                (SELECT  TOP 1 
                    CASE 
                        WHEN RN > 1 THEN 1 
                    ELSE 0 
                    END 
                FROM (
                    SELECT 
                        ROW_NUMBER()OVER(PARTITION BY PublishLogId, 
                        SourceItem, 
                        ItemName, 
                        LocationName, 
                        ParameterTypeName, 
                        Quantity,
                        BucketType, 
                        FiscalYearWorkWeekNbr, 
                        FabProcess, 
                        DotProcess, 
                        LrpDIeNm,
                        TechNode, 
                        SourceApplicationName 
                        ORDER BY FiscalYearWorkWeekNbr) RN
                    FROM [dbo].[StgSnOPCompassMRPFabRouting] WITH (NOLOCK)
                ) A
                WHERE RN > 1
                );
        BEGIN 
            IF (@verifyDup = 1)
            BEGIN
                RAISERROR('Duplicates found in the table dbo.SnOPCompassMRPFabRouting. Please verify and contact Hana team.',16,1)
            END

			SELECT  PublishLogId, 
				SourceItem, 
				ItemName, 
				LocationName, 
				ParameterTypeName, 
				Quantity,
				OriginalQuantity,
				BucketType, 
				FiscalYearWorkWeekNbr, 
				FabProcess, 
				DotProcess, 
				LrpDIeNm,
				TechNode, 
				SourceApplicationName, 
				IsOverride
			INTO #TmpStgSnOPCompassMRPFabRouting
			FROM dbo.SnOPCompassMRPFabRouting WITH (NOLOCK)
			WHERE IsOverride = 0;
      
            MERGE [dbo].[SnOPCompassMRPFabRoutingHist] AS S
            USING #TmpStgSnOPCompassMRPFabRouting AS Stg
            ON (Stg.PublishLogId = S.PublishLogId
                AND Stg.SourceItem = S.SourceItem
                AND Stg.ItemName = S.ItemName
                AND Stg.LocationName = S.LocationName
                AND Stg.ParameterTypeName = S.ParameterTypeName
                AND Stg.FiscalYearWorkWeekNbr = S.FiscalYearWorkWeekNbr
                AND Stg.FabProcess = S.FabProcess
                AND Stg.BucketType = S.BucketType
                AND Stg.LrpDieNm = S.LrpDieNm
                AND Stg.TechNode = S.TechNode
                AND Stg.SourceApplicationName = S.SourceApplicationName
                AND Stg.DotProcess = S.DotProcess
                )
            WHEN NOT MATCHED BY TARGET THEN
                INSERT
                (
                    PublishLogId
                    ,SourceItem
                    ,ItemName
                    ,LocationName
                    ,ParameterTypeName
                    ,Quantity
                    ,OriginalQuantity
                    ,BucketType
                    ,FiscalYearWorkWeekNbr
                    ,FabProcess
                    ,DotProcess
                    ,LrpDieNm
                    ,TechNode
                    ,SourceApplicationName
                    ,IsOverride
                    ,CreatedOn
                    ,CreatedBy
                )
                VALUES
                (
                    Stg.PublishLogId
                    ,Stg.SourceItem
                    ,ISNULL(Stg.ItemName, '')
                    ,Stg.LocationName
                    ,Stg.ParameterTypeName
                    ,Stg.Quantity
                    ,Stg.Quantity
                    ,Stg.BucketType
                    ,Stg.FiscalYearWorkWeekNbr
                    ,Stg.FabProcess
                    ,Stg.DotProcess
                    ,Stg.LrpDieNm
                    ,Stg.TechNode
                    ,Stg.SourceApplicationName
                    ,0
                    ,GETDATE()
                    ,ORIGINAL_LOGIN()
                );       
        END 
        
		DELETE FROM S
		FROM [dbo].[SnOPCompassMRPFabRouting] AS S
		WHERE IsOverride = 0

		MERGE [dbo].[SnOPCompassMRPFabRouting] AS S
		USING [dbo].[StgSnOPCompassMRPFabRouting] AS Stg
		ON (Stg.PublishLogId = S.PublishLogId
			AND Stg.SourceItem = S.SourceItem
			AND Stg.ItemName = S.ItemName
			AND Stg.LocationName = S.LocationName
			AND Stg.ParameterTypeName = S.ParameterTypeName
			AND Stg.FiscalYearWorkWeekNbr = S.FiscalYearWorkWeekNbr
			AND Stg.FabProcess = S.FabProcess)
		WHEN MATCHED THEN
		UPDATE SET
			S.Quantity = Stg.Quantity
			,S.OriginalQuantity = Stg.Quantity
			,S.BucketType = Stg.BucketType
			,S.DotProcess = Stg.DotProcess
			,S.LrpDieNm = Stg.LrpDieNm
			,S.TechNode = Stg.TechNode
			,S.SourceApplicationName = Stg.SourceApplicationName
			,S.IsOverride = 0
			,S.UpdatedOn = GETDATE()
			,S.UpdatedBy = ORIGINAL_LOGIN()
			,S.UpdateComment = 'Initial Load'
		WHEN NOT MATCHED BY TARGET THEN
			INSERT
			(
				PublishLogId
				,SourceItem
				,ItemName
				,LocationName
				,ParameterTypeName
				,Quantity
				,OriginalQuantity
				,BucketType
				,FiscalYearWorkWeekNbr
				,FabProcess
				,DotProcess
				,LrpDieNm
				,TechNode
				,SourceApplicationName
				,IsOverride
				,CreatedOn
				,CreatedBy
				,UpdatedOn
				,UpdatedBy
				,UpdateComment
			)
			VALUES
			(
				Stg.PublishLogId
				,Stg.SourceItem
				,ISNULL(Stg.ItemName, '')
				,Stg.LocationName
				,Stg.ParameterTypeName
				,Stg.Quantity
				,Stg.Quantity
				,Stg.BucketType
				,Stg.FiscalYearWorkWeekNbr
				,Stg.FabProcess
				,Stg.DotProcess
				,Stg.LrpDieNm
				,Stg.TechNode
				,Stg.SourceApplicationName
				,0
				,GETDATE()
				,ORIGINAL_LOGIN()
				,GETDATE()
				,ORIGINAL_LOGIN()
				,'Initial Load'
			);
			
	-- End Main Logic
    
	-- Log Handling ********************************************************
	EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Info'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @Message
      , @Status = 'END'
      , @Exception = NULL
      , @BatchId = @BatchId;

    RETURN 0;
END TRY
BEGIN CATCH
    SELECT
        @ReturnErrorMessage =
        'Severity: ' + CAST(ERROR_SEVERITY() AS VARCHAR(50)) + ' State: ' + CAST(ERROR_STATE() AS VARCHAR(50))
        + ' Number: ' + CAST(ERROR_NUMBER() AS VARCHAR(50)) + ' Line: '
        + ISNULL(CAST(ERROR_LINE() AS VARCHAR(10)), '<UNKNOWN>') + ' Procedure: '
        + ISNULL(ERROR_PROCEDURE(), '<Dynamic Context>') + ' Error: ' + ISNULL(ERROR_MESSAGE(), '<UNKNOWN>');


    EXEC dbo.UspAddApplicationLog
        @LogSource = 'Database'
      , @LogType = 'Error'
      , @Category = 'Etl'
      , @SubCategory = @ErrorLoggedBy
      , @Message = @CurrentAction
      , @Status = 'ERROR'
      , @Exception = @ReturnErrorMessage
      , @BatchId = @BatchId;

     --re-throw the error
    THROW;

END CATCH;
