




  
CREATE PROC dbo.[UspGuiEsdFetchControls]


AS
/* Testing harness
	EXEC gui.UspFetchControls
--*/


		SELECT	
				[ControlID]
				,[ControlTypeID]
				,COALESCE([ControlName],'') as ControlName
				,[ControlLabel]
				,COALESCE([ControlSizeID],1) AS ControlSizeID
				,COALESCE([ControlOfficeImageString],'') AS ControlOfficeImageString
				,COALESCE([PopulateControlDBItem],'') AS PopulateControlDBItem
				,COALESCE([ControlColumnName]	 ,'') AS ControlColumnName
				,COALESCE([IDColumnName]		 ,'') AS IDColumnName
				,COALESCE([ExecControlDBItem],'') AS ExecControlDBItem

				,[IsVisibleOnInit]						
		FROM	dbo.[GuiUIControl]


