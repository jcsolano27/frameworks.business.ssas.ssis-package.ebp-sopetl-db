





  
CREATE PROC dbo.[UspGuiEsdFetchDataColumns]
(@DataSheetID INT
)

AS
/* Testing harness

--*/
		SELECT 
			DC.DataSheetID
			,DC.DataColumnID
			,DC.DataColumnName
			,isLocked
			,isXMLColumn
			,ValidationProc
		FROM dbo.GuiUiDataColumn DC
		WHERE 1=1 
			AND DC.DataSheetID = @DataSheetID
		--ORDER BY 1


