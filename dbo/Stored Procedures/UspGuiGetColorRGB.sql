


  
CREATE PROC  dbo.[UspGuiGetColorRGB]
(@ColorID INT = 0
)

AS
/* Testing harness
	select * from gui.[fnGetColorRGB](1)
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


