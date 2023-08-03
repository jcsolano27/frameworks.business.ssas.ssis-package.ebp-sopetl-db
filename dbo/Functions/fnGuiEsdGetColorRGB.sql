



  
CREATE FUNCTION [dbo].[fnGuiEsdGetColorRGB]
(@ColorID INT = 1
)
RETURNS TABLE 
AS
/* Testing harness
	select * from dbo.[fnGuiEsdGetColorRGB](0)
--*/

RETURN


		SELECT	TOP(1)
			ColorID,
			ColorName,
			RedVal,
			GreenVal,
			BlueVal
		FROM dbo.[GuiUIColor]
		WHERE (ColorID = @ColorID);


		--ORDER BY 1



