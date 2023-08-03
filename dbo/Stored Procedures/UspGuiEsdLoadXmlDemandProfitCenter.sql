




CREATE PROC [dbo].[UspGuiEsdLoadXmlDemandProfitCenter] (@xmlString TEXT,@LoadedByTool varchar(25))
AS
/****************************************************************************************
DESCRIPTION: This proc loads ESD Source Version Bypass Data to the Recon Database
*****************************************************************************************/
BEGIN
	SET NOCOUNT ON
/*-- TEST HARNESS
	EXEC [esd].[UspGuiEsdLoadXmlDemandProfitCenter]	 @xmlString = '<list><record ProfitCenterID=2380></list>' @LoadedByTool='ESD_UI'
-- TEST HARNESS */
 DECLARE @idoc				int,
		@now				datetime,
		@user_id			varchar(50)
		
SET @now = GETDATE()		
--IF @user_id IS NULL
SET @user_id = SYSTEM_USER

EXEC sp_xml_preparedocument @idoc OUTPUT, @xmlString


		IF OBJECT_ID('tempdb..#TmpProfitCenterAdj') IS NOT NULL drop table #TmpProfitCenterAdj
		CREATE TABLE #TmpProfitCenterAdj(

			ProfitCenterID INT
		) 

		INSERT INTO #TmpProfitCenterAdj(
			ProfitCenterID
		)
	SELECT  ProfitCenterID

		  FROM 	OPENXML (@idoc, '/list/record', 2)
			WITH 
			   (
					ProfitCenterID int
			   ) T1

EXEC sp_xml_removedocument @idoc
		--DELETE Rows where an Adjustment has been made, but then deleted
		DELETE  T1
		FROM [dbo].[GuiUIDemandProfitCenter] T1
	
		--UPDATE Rows that have already been eltered but the Quantity has changed
		INSERT INTO [dbo].[GuiUIDemandProfitCenter]
		SELECT 
		B.[ProfitCenterNm]
		,a.ProfitCenterID
		FROM
		#TmpProfitCenterAdj A
		JOIN [dbo].[ProfitCenterHierarchy] b
		ON a.ProfitCenterID = b.ProfitCenterCd
END



