CREATE TABLE [dbo].[ProfitCenterHierarchy] (
    [ProfitCenterHierarchyId]      INT           NULL,
    [ProfitCenterCd]               INT           NOT NULL,
    [ProfitCenterNm]               VARCHAR (100) NOT NULL,
    [IsActive]                     BIT           CONSTRAINT [DF_ProfitCenters_IsActive] DEFAULT ((1)) NOT NULL,
    [DivisionDsc]                  VARCHAR (100) NULL,
    [GroupDsc]                     VARCHAR (100) NULL,
    [SuperGroupDsc]                VARCHAR (100) NULL,
    [CreatedOn]                    DATETIME      CONSTRAINT [DF_ProfitCenters_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                    VARCHAR (25)  CONSTRAINT [DF_ProfitCenters_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [DivisionNm]                   VARCHAR (100) NULL,
    [GroupNm]                      VARCHAR (100) NULL,
    [SuperGroupNm]                 VARCHAR (100) NULL,
    [GroupProfitCenterDescription] VARCHAR (20)  NULL,
    CONSTRAINT [PK_ProfitCenters] PRIMARY KEY CLUSTERED ([ProfitCenterCd] ASC)
);


GO

CREATE     TRIGGER [dbo].[TrgProfitCenterHierarchyCDC]
ON [dbo].[ProfitCenterHierarchy]
AFTER INSERT, UPDATE, DELETE
AS BEGIN

-- TO DO - UPDATE TABLE dq.Configuration FOR THE DATA CONTROL COLUMNS (LASTSUCCESSFULRUN, CURRENTSTATUS)
-- APPLY BEGIN CATCH TO FAIL PROPERLY AND UPDATE CONFIG WITH FAIL STATUS

----/*********************************************************************************
----    Purpose:		This trigger was designed to monitor the [dbo].[ProfitCenterHierarchy] table, in order to give business the view of changes this table
----					suffers on a daily basis. It loads the [dbo].[ProfitCenterHierarchyCDC] table that will be used after in a PBI report with a view.
----    Source:			[dbo].[ProfitCenterHierarchy]
----    Desrtination:   [dbo].[ProfitCenterHierarchyCDC]

----    Called by:      INSERT, UPDATE, DELETE

----    Result sets:    None

----    Parameters: None

----    Return Codes: None

----    Exceptions: None expected

----    Date        User            Description
----***************************************************************************-
----    2022-12-20  hmanentx        Initial Release

----*********************************************************************************/

	DECLARE @CONST_DataQualityId_ProfitCenterCdc INT = [dbo].[CONST_DataQualityId_ProfitCenterCdc]()
	DECLARE @BatchIdLocal varchar(255)
	SET @BatchIdLocal = 'dbo.TrgProfitCenterHierarchyCDC.' + CONVERT(varchar(50), SYSDATETIME()) + '.' + ORIGINAL_LOGIN()

	BEGIN TRY

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = 'DQ'
			, @SubCategory = 'Trigger [dbo].[TrgProfitCenterHierarchyCDC]'
			, @Message = 'Start'
			, @Status = 'BEGIN'
			, @Exception = NULL
			, @BatchId = @BatchIdLocal;

		-- Getting the new rows
		SELECT
			I.ProfitCenterHierarchyId
			,I.ProfitCenterCd
			,I.ProfitCenterNm
			,I.IsActive
			,I.DivisionDsc
			,I.GroupDsc
			,I.SuperGroupDsc
			,I.CreatedOn
			,I.CreatedBy
			,I.DivisionNm
			,I.GroupNm
			,I.SuperGroupNm
			,'INSERT' AS OperationDsc
		INTO #NewRows
		FROM inserted I
		WHERE NOT EXISTS (SELECT 1 FROM deleted D WHERE D.ProfitCenterCd = I.ProfitCenterCd)

		-- Getting the old values for updated rows that have changes
		SELECT
			D.ProfitCenterHierarchyId
			,D.ProfitCenterCd
			,D.ProfitCenterNm
			,D.IsActive
			,D.DivisionDsc
			,D.GroupDsc
			,D.SuperGroupDsc
			,D.CreatedOn
			,D.CreatedBy
			,D.DivisionNm
			,D.GroupNm
			,D.SuperGroupNm
			,'UPDATE' AS OperationDsc
		INTO #UpdatedRows
		FROM inserted I
		INNER JOIN deleted D ON D.ProfitCenterCd = I.ProfitCenterCd
		WHERE
			I.ProfitCenterHierarchyId <> D.ProfitCenterHierarchyId
			OR I.ProfitCenterNm <> D.ProfitCenterNm
			OR I.IsActive <> D.IsActive
			OR I.DivisionDsc <> D.DivisionDsc
			OR I.GroupDsc <> D.GroupDsc
			OR I.SuperGroupDsc <> D.SuperGroupDsc
			OR I.DivisionNm <> D.DivisionNm
			OR I.GroupNm <> D.GroupNm
			OR I.SuperGroupNm <> D.SuperGroupNm

		-- THIS PROCESS DON`T HAVE PHYSICAL DELETION, SO IT WILL BE HANDLED BY UPDATED ROWS

		-- Inserting the rows into the control table
		INSERT INTO dbo.ProfitCenterHierarchyCDC
		SELECT
			N.ProfitCenterHierarchyId
			,N.ProfitCenterCd
			,N.ProfitCenterNm
			,N.IsActive
			,N.DivisionDsc
			,N.GroupDsc
			,N.SuperGroupDsc
			,N.CreatedOn
			,N.CreatedBy
			,N.DivisionNm
			,N.GroupNm
			,N.SuperGroupNm
			,N.OperationDsc
			,GETDATE() AS CDCDate
		FROM #NewRows N
		UNION
		SELECT
			U.ProfitCenterHierarchyId
			,U.ProfitCenterCd
			,U.ProfitCenterNm
			,U.IsActive
			,U.DivisionDsc
			,U.GroupDsc
			,U.SuperGroupDsc
			,U.CreatedOn
			,U.CreatedBy
			,U.DivisionNm
			,U.GroupNm
			,U.SuperGroupNm
			,U.OperationDsc
			,GETDATE() AS CDCDate
		FROM #UpdatedRows U

		UPDATE DQC
		SET
			LastSuccessfulRun = GETDATE()
			,CurrentStatus = 'SUCCESS'
		FROM dq.Configuration DQC
		WHERE DQC.Id = @CONST_DataQualityId_ProfitCenterCdc

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = 'DQ'
			, @SubCategory = 'Trigger [dbo].[TrgProfitCenterHierarchyCDC]'
			, @Message = 'Finish'
			, @Status = 'END'
			, @Exception = NULL
			, @BatchId = @BatchIdLocal;

	END TRY
	BEGIN CATCH

		UPDATE DQC
		SET
			CurrentStatus = 'FAILURE'
		FROM dq.Configuration DQC
		WHERE DQC.Id = @CONST_DataQualityId_ProfitCenterCdc

		EXEC dbo.UspAddApplicationLog
			@LogSource = 'Database'
			, @LogType = 'Info'
			, @Category = 'DQ'
			, @SubCategory = 'Trigger [dbo].[TrgProfitCenterHierarchyCDC]'
			, @Message = 'Failure'
			, @Status = 'ERROR'
			, @Exception = @@ERROR
			, @BatchId = @BatchIdLocal;

	END CATCH

END