CREATE   PROC [dbo].[UspGuiEsdLoadXmlESDRoles] (@xmlString TEXT,@LoadedByTool varchar(25))
AS
/****************************************************************************************
DESCRIPTION: This proc loads ESD Source Version Bypass Data to the Recon Database
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [dbo].[UspGuiEsdLoadXmlMRPDataDisplay]	 @xmlString = '<list><record EsdVersionId=115 IsMRP=True/></list>' @LoadedByTool='ESD_UI'
-- TEST HARNESS */
 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER


--DECLARE @xmlString varchar(max) = '<list><record><EsdUserRoleId>3</EsdUserRoleId><UserNm>amr\ghiverso</UserNm><RoleNm>None</RoleNm><AddRle>Y</AddRle></record>></list>'
--DECLARE @LoadedByTool varchar(255) = 'Excel Workbook'

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString



		IF OBJECT_ID('tempdb..#ESDRoles') IS NOT NULL drop table #ESDRoles
		CREATE TABLE #ESDRoles(
		[EsdUserRoleId] INT,
			[UserNm] varchar(50),
			[RoleNm] varchar(50)
		) 

		INSERT INTO #ESDRoles(
		[EsdUserRoleId],
			[UserNm],
			[RoleNm]
			
		)
	SELECT  [EsdUserRoleId],
	[UserNm],
			[RoleNm]
			

		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
			   [EsdUserRoleId] INT,
					[UserNm] varchar(50),
			[RoleNm] varchar(50)
		--	[Add] varchar(2)
			   ) T1

--			   select * from #ESDRoles


EXEC sp_xml_removedocument @idoc


		--DELETE Rows where an Adjustment has been made, but then deleted
		DELETE  T1
		FROM [dbo].[EsdUserRole] T1
		JOIN #ESDRoles T2
			ON T2.[UserNm]= T1.[UserNm]
			AND T2.EsdUserRoleId = T1.EsdUserRoleId
			WHERE T2.[RoleNm] = 'None'

		--UPDATE Rows that have already been eltered but the Quantity has changed
		UPDATE T1 
			SET T1.[RoleNm] = T2.[RoleNm]
		FROM [dbo].[EsdUserRole] T1
		JOIN #ESDRoles T2
			ON T2.[UserNm]= T1.[UserNm]
			AND T2.EsdUserRoleId = T1.EsdUserRoleId
		WHERE T2.[RoleNm] <> T1.[RoleNm]

		--INSERT New Records Regardless of Whether record exists /////where FgItemGroupOrWafer does not Exist
		INSERT INTO [dbo].[EsdUserRole]
				   (
					[UserNm]
					,[RoleNm]
					,[CreatedOn]
					,[CreatedBy]
					,[UpdatedOn]
					,[UpdatedBy]

				   )

				SELECT [UserNm]
					,[RoleNm]
					,@now
					,@user_id
					,@now
					,@user_id
				FROM #ESDRoles T1
				WHERE [EsdUserRoleId] NOT IN
				( SELECT [EsdUserRoleId] FROM [dbo].[EsdUserRole] )
				AND [RoleNm] <> 'None'




END