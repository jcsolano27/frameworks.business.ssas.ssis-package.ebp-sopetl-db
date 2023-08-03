CREATE    PROC  [dbo].[UspLoadItemCharacteristicDetail]
AS

BEGIN

----/*********************************************************************************
     
----    Purpose: Loads data from HANA source to ItemCharacteristicDetail destination
----    Sources: [dbo].StgItemCharacteristicDetail
----    Destinations: [dbo].ItemCharacteristicDetail

----    Called by:      SSIS
         
----    Result sets:    None
     
----    Parameters: None
         
----    Return Codes:   0 = Success
----                    < 0 = Error
----                    > 0 (No warnings for this SP, should never get a returncode > 0)
     
----    Exceptions:     None expected
     
----    Date        User            Description
----***************************************************************************-
----    2023-05-15  fjunio2x        Initial Release
----    2023-07-07  hmanentx        Adding two new columns to store ItemClass and 
----	2023-07-28	atairumx		Adding concat logic to CharacteristicValue field and ajjustments in MERGE
----*********************************************************************************/

	SET NOCOUNT ON
	Declare 
		@Data	DateTime = getdate(),
	    @Login  Varchar(20) = 	original_login()

	BEGIN TRY

		-- Error and transaction handling setup ********************************************************
		DECLARE
			@ReturnErrorMessage VARCHAR(MAX)
		  , @ErrorLoggedBy      VARCHAR(512) = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)
		  , @CurrentAction      VARCHAR(4000)
		  , @DT                 VARCHAR(50)  = SYSDATETIME()
		  , @Message            VARCHAR(MAX)
		  , @BatchId			VARCHAR(512)

		SET @CurrentAction = @ErrorLoggedBy + ': SP Starting'

		SET @BatchId = @ErrorLoggedBy + '.' + @DT + '.' + ORIGINAL_LOGIN()

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
		  , @LogType = 'Info'
		  , @Category = 'Etl'
		  , @SubCategory = @ErrorLoggedBy
		  , @Message = @Message
		  , @Status = 'BEGIN'
		  , @Exception = NULL
		  , @BatchId = @BatchId;

		MERGE [dbo].ItemCharacteristicDetail AS ICD --Destination Table
		USING
		(
			SELECT DISTINCT I.ProductDataManagementItemId,
				I.ProductDataManagementItemClassNm,
				I.CharacteristicNm,
				SUBSTRING(R.CharacteristicValue,1,IIF(LEN(R.CharacteristicValue)=0,0,LEN(R.CharacteristicValue)-1)) CharacteristicValue
			FROM [dbo].StgItemCharacteristicDetail I
			--------------------------------------------------------------------------------------------
			--BEGIN TEMPORARY FIX------------------------------------------------------------------------
			--------------------------------------------------------------------------------------------
			/*Temporary fix to solve a problem with a specific item that has the same "ProductDataManagementItemId","ProductDataManagementItemClassNm", 
			  and "ProductDataManagementItemCharacteristicNm" but "CharacteristicValue" different.  The item with the problem is '2000-299-803'
			  We are investigating to figure out the best solution for it and apply a final solution.

			  "ProductDataManagementItemId" | "ProductDataManagementItemClassNm" | "ProductDataManagementItemCharacteristicNm" | "CharacteristicValue"
				2000-299-803				|				UPI_SORT			 |		PS_DOT_PROCESS						   |	1222.4
				2000-299-803				|				UPI_SORT			 |		PS_DOT_PROCESS						   |	1222.4-6

				This piece of code concatenate the column "CharacteristicValue" in case of occur the situation mentioned above.
			*/
			CROSS APPLY
			(
				SELECT CharacteristicValue + ' | '
				FROM [dbo].StgItemCharacteristicDetail C
				WHERE I.ProductDataManagementItemId = C.ProductDataManagementItemId
				AND I.ProductDataManagementItemClassNm = C.ProductDataManagementItemClassNm
				AND I.CharacteristicNm = C.CharacteristicNm
				FOR XML PATH('')
			--------------------------------------------------------------------------------------------
			--END TEMPORARY FIX------------------------------------------------------------------------
			--------------------------------------------------------------------------------------------
			)R(CharacteristicValue)
			WHERE I.ProductDataManagementItemId IS NOT NULL
				AND I.ProductDataManagementItemClassNm IS NOT NULL
				AND I.CharacteristicValue IS NOT NULL
		) AS SICD --Source Table
		ON (
				ICD.ProductDataManagementItemId = SICD.ProductDataManagementItemId 
				AND ICD.CharacteristicNm	= SICD.CharacteristicNm
				AND COALESCE(ICD.ProductDataManagementItemClassNm, '') = COALESCE(SICD.ProductDataManagementItemClassNm, '')				
			)
		WHEN MATCHED AND ICD.CharacteristicValue <> SICD.CharacteristicValue THEN
			UPDATE SET		
                     ICD.CharacteristicValue				= SICD.CharacteristicValue	
                    , ICD.Createdon							= @Data
                    , ICD.CreatedBy							= @Login					  
		WHEN NOT MATCHED BY TARGET
			THEN
				INSERT
				VALUES 
					(
					    SICD.ProductDataManagementItemId
					, SICD.ProductDataManagementItemClassNm
				    , SICD.CharacteristicNm
				    , SICD.CharacteristicValue
					, @Data
					, @Login
					);

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

	END CATCH

	SET NOCOUNT OFF

END