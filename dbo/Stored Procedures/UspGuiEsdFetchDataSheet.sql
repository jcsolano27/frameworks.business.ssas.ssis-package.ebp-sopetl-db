




  
CREATE PROC dbo.[UspGuiEsdFetchDataSheet]
(@DataSheetID INT = null
)

AS
/* Testing harness
	EXEC gui.UspFetchDataSheet
--*/

IF @DataSheetID IS NULL
	BEGIN
			SELECT	DISTINCT 
				[DataSheetID]
				,[DataSheetName]
				,[DataSheetType]
				,FetchProcName
				,LoadProcName
				,Coalesce([ColorID],1) as ColorID
			FROM [dbo].[GuiUIDataSheet]
	END
ELSE
	BEGIN
			SELECT	DISTINCT 
				[DataSheetID]
				,[DataSheetName]
				,[DataSheetType]
				,FetchProcName
				,LoadProcName
				,Coalesce([ColorID],1) as ColorID
			FROM [dbo].[GuiUIDataSheet]
			WHERE DataSheetID = @DataSheetID
	END
		



