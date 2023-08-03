

CREATE PROC [sop].[UspLoadCustomer]

AS
----/*********************************************************************************

----    Purpose:        This proc is used to load data from Denodo SopCustomerHierarchy to SVD database   
----                    Source:      dbo.SnOPCustomerHierarchy
----                    Destination: sop.Customer

----    Called by:      SSIS

----    Result sets:    None

----    Parameters        

----    Date        User            Description
----***************************************************************************-
----    2023-06-09  vitorsix        Created
----	2023-07-16	ldesousa		HierarchyLevelId changed to 2 and Source System pointed to IBP (still need to double check)
----	2023-07-27	vitorsix		HierarchyLevelId changed back to 5, source changed dbo.SnOPCustomerHierarchy and Source System pointed to SVD
----*********************************************************************************/

-- EXEC [sop].[UspLoadCustomer]
-- EXEC sop.UspLoadActualSales
-- EXEC sop.UspLoadPlanningFigure 3
-- EXEC sop.uspReportSnOPFetchDimCustomer

BEGIN
	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF;
	DECLARE 
			@BatchId VARCHAR(100) = 'LoadCustomer.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER,
			@SVD INT = [sop].[CONST_SourceSystemId_Svd]();

	BEGIN TRY
		--Logging Start
		EXEC sop.UspAddApplicationLog 'Database', 'Info', 'LoadCustomer', 'UspLoadCustomer','Load Customer Data', 'BEGIN', NULL, @BatchId



		MERGE sop.Customer AS TARGET
		USING (
					SELECT 
						 CustomerNodeId as CustomerId
						,CustomerGroup as CustomerNm
						,BusinessNameTypeDsc as CustomerDsc
						,HostedRegion as HostedRegionCd
						,CustomerType as CustomerTypeCd
						,CustomerNodeId as SourceCustomerId
						,iif(ActiveInd = 'Y',1,0) as ActiveInd
						,CreateDtm as CreatedOnDtm
						,CreateUserNm as CreatedByNm
						,@SVD as SourceSystemId
					FROM dbo.SnOPCustomerHierarchy
					WHERE HierarchyLevelId = '5'
					)
				AS SOURCE
		ON SOURCE.CustomerId = TARGET.CustomerId

		WHEN NOT MATCHED BY TARGET THEN
		INSERT (
						 CustomerId
						,CustomerNm
						,CustomerDsc
						,HostedRegionCd
						,CustomerTypeCd
						,SourceCustomerId
						,ActiveInd
						,CreatedOnDtm
						,CreatedByNm
						,ModifiedOnDtm
						,ModifiedByNm
						,SourceSystemId
		       )

		VALUES (
				         SOURCE.CustomerId
						,SOURCE.CustomerNm
						,SOURCE.CustomerDsc
						,SOURCE.HostedRegionCd
						,SOURCE.CustomerTypeCd
						,SOURCE.SourceCustomerId
						,SOURCE.ActiveInd
						,DEFAULT
						,DEFAULT
						,DEFAULT
						,DEFAULT
						,SOURCE.SourceSystemId
				)
		
		WHEN NOT MATCHED BY SOURCE THEN

						UPDATE SET TARGET.ActiveInd = 0
		
		WHEN MATCHED THEN 
						UPDATE SET 
						 TARGET.CustomerNm = SOURCE.CustomerNm
						,TARGET.CustomerDsc = SOURCE.CustomerDsc
						,TARGET.HostedRegionCd = SOURCE.HostedRegionCd
						,TARGET.CustomerTypeCd = SOURCE.CustomerTypeCd
						,TARGET.SourceCustomerId = SOURCE.SourceCustomerId
						,TARGET.ActiveInd = SOURCE.ActiveInd
						,TARGET.ModifiedOnDtm = GETDATE()
						,TARGET.ModifiedByNm = ORIGINAL_LOGIN()
						,TARGET.SourceSystemId = SOURCE.SourceSystemId ;

		--Logging End
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'LoadCustomer', 'UspLoadCustomer','Load Customer Data', 'END', NULL, @BatchId
		

	END TRY
	BEGIN CATCH 
		
		--Add Entry in Log Table
		DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
		EXEC sop.UspAddApplicationLog 'Database', 'Info', 'LoadCustomer','UspLoadCustomer', 'Load Customer Data','ERROR', @ErrorMsg, @BatchId

		RAISERROR(@ErrorMsg, 16, 1)
	END CATCH
	
	SET NOCOUNT OFF
	SET ANSI_WARNINGS ON;
END
