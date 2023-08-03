


/************************************************************************************
  DESCRIPTION: Add new entry into the [ApplicationLog] table
*************************************************************************************/
CREATE PROC [sop].[UspAddApplicationLog]
(	@LogSource   VARCHAR(255),					-- "WinClient", "WebReports"
	@LogType     VARCHAR(255),					-- "Info", "Warning", "Critical", "Error", "Debug"
	@Category    VARCHAR(1000),
	@SubCategory VARCHAR(1000),
	@Message     VARCHAR(MAX),
	@Status		 VARCHAR(25),
	@Exception   VARCHAR(MAX)  = NULL,
	@BatchId     VARCHAR(1000) = NULL
	
)
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
		-- Validate parameters
		IF (@LogSource IS NULL) RAISERROR('@LogSource cannot be NULL',16,1)
		IF (@LogType IS NULL) RAISERROR('@LogType cannot be NULL',16,1)
		IF (@Category IS NULL) RAISERROR('@Category cannot be NULL',16,1)
		IF (@Status IS NULL) RAISERROR('@Status cannot be NULL',16,1)

		
		BEGIN
			-- Log event
			INSERT INTO sop.ApplicationLog
			(	[LogDate],
				[LogSource],
				[LogType],
				[Category],
				[SubCategory],
				[Message],
				[Status],
				[Exception],
				[BatchId],
				[HostName],
				[CreatedOn],
				[CreatedBy]
			) VALUES
				(	GETUTCDATE(),
					@LogSource,
					@LogType,
					@Category,
					@SubCategory,
					@Message,
					@Status,
					@Exception,
					@BatchId,
					HOST_NAME(),
					GETDATE(),
					SYSTEM_USER
				)
		END
	END TRY
	BEGIN CATCH
		DECLARE @ErrorMessage VARCHAR(MAX);
		SET @ErrorMessage = 'ERROR_MESSAGE: ' + ISNULL(ERROR_MESSAGE(),'') + ' / ERROR_PROCEDURE: ' + ISNULL(ERROR_PROCEDURE(),'') + ' / ERROR_LINE: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR),'')
		RAISERROR(@ErrorMessage,16,1)
	END CATCH

END

