

CREATE PROC [sop].[UspLoadProduct]
AS

----/*********************************************************************************  

----    Purpose:        This proc is used to load data from SVD Product tables and load it into SOP schema for IDM 2.0 efforts    
----                    Source:      [dbo].[SnopDemandProductHierarchy]/[dbo].[SnopSupplyProductHierarchy]/[dbo].[ItemCharacteristicDetail]  
----                    Destination: [sop].[Product]  

----    Called by:      SSIS  

----    Result sets:    None  

---- Parameters          

----    Date			User            Description  
----***************************************************************************-  
----    2023-06-26		ldesousa		Initial Release  
----    2023-07-20		jcsolano		Addition of Die Prep  
----	2023-07-31		ldesousa		Changing SORT_UPI ProductName attribute from MM-CODE-NAME to PS-MFG-DEVICE
----	2023-07-31		ldesousa		Changing SORT_UPI ProductName to point to ItemId because we still don't know what attribute to use for NAME
----	2023-08-02		ldesousa		Changing SORT_UPI ProductName to point to Description - Business confirmed this is the right column to use
----	2023-08-03		ldesousa		Adding UspLoadProductAttribute to the end of the process
----*********************************************************************************/  

BEGIN
    SET NOCOUNT ON;
    DECLARE @BatchId VARCHAR(100) = 'LoadProduct.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER;
    DECLARE @EmailMessage VARCHAR(1000) = 'LoadProduct Successful';
    DECLARE @Prog VARCHAR(255);

    DECLARE @CONST_ProductTypeId_SnopDemandProduct	INT = ( SELECT [sop].[CONST_ProductTypeId_SnopDemandProduct]() );
    DECLARE @CONST_ProductTypeId_SnopSupplyProduct	INT = ( SELECT [sop].[CONST_ProductTypeId_SnopSupplyProduct]() );
    DECLARE @CONST_ProductTypeId_UpiSort			INT = ( SELECT [sop].[CONST_ProductTypeId_UpiSort]() );
    DECLARE @CONST_ProductTypeId_DiePrep INT = 4;

    DECLARE @CONST_SourceSystemId_Svd INT = ( SELECT [sop].[CONST_SourceSystemId_Svd]() );

    /*  
 ---------  
 EXEC [sop].[UspLoadProduct]  
 ---------  
 */

    BEGIN TRY
        --Logging Start  
        EXEC sop.UspAddApplicationLog 'Database',
                                      'Info',
                                      'LoadProduct',
                                      'UspLoadProduct',
                                      'Load Product Data',
                                      'BEGIN',
                                      NULL,
                                      @BatchId;

        -- Loading SnopDemandProducts  
        MERGE [sop].[Product] AS TARGET
        USING
        (
            SELECT SnOPDemandProductNm AS ProductNm,
                   @CONST_ProductTypeId_SnopDemandProduct AS ProductTypeId,
                   IsActive AS ActiveInd,
                   CAST(SnOPDemandProductId AS VARCHAR(30)) AS SourceProductId,
                   @CONST_SourceSystemId_Svd AS SourceSystemId
            FROM dbo.SnOPDemandProductHierarchy
            WHERE IsActive = 1
        ) AS SOURCE
        ON SOURCE.SourceProductId = TARGET.SourceProductId ------ ADD PRODUCT TYPE IN THE MERGE  
           AND SOURCE.ProductTypeId = TARGET.ProductTypeId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                ProductNm,
                ProductTypeId,
                ActiveInd,
                SourceProductId,
                SourceSystemId
            )
            VALUES
            (SOURCE.ProductNm, SOURCE.ProductTypeId, SOURCE.ActiveInd, SOURCE.SourceProductId, SOURCE.SourceSystemId)
        WHEN MATCHED THEN
            UPDATE SET ------ APPLY "AND" IN MATCHED Conditions  
                TARGET.ProductNm = SOURCE.ProductNm,
                TARGET.ProductTypeId = SOURCE.ProductTypeId,
                TARGET.ActiveInd = SOURCE.ActiveInd,
                TARGET.SourceProductId = SOURCE.SourceProductId,
                TARGET.SourceSystemId = SOURCE.SourceSystemId,
                TARGET.ModifiedOn = GETDATE(),
                TARGET.ModifiedBy = ORIGINAL_LOGIN()
        WHEN NOT MATCHED BY SOURCE AND TARGET.ProductTypeId = @CONST_ProductTypeId_SnopDemandProduct THEN
            UPDATE SET TARGET.ActiveInd = 0;

        -- Loading SnopSupplyProducts  
        MERGE [sop].[Product] AS TARGET
        USING
        (
            SELECT SnOPSupplyProductNm AS ProductNm,
                   @CONST_ProductTypeId_SnopSupplyProduct AS ProductTypeId,
                   IsActive AS ActiveInd,
                   CAST(SnOPSupplyProductId AS VARCHAR(30)) AS SourceProductId,
                   @CONST_SourceSystemId_Svd AS SourceSystemId
            FROM dbo.SnOPSupplyProductHierarchy
            WHERE IsActive = 1
        ) AS SOURCE
        ON SOURCE.SourceProductId = TARGET.SourceProductId
           AND SOURCE.ProductTypeId = TARGET.ProductTypeId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                ProductNm,
                ProductTypeId,
                ActiveInd,
                SourceProductId,
                SourceSystemId
            )
            VALUES
            (SOURCE.ProductNm, SOURCE.ProductTypeId, SOURCE.ActiveInd, SOURCE.SourceProductId, SOURCE.SourceSystemId)
        WHEN MATCHED THEN
            UPDATE SET TARGET.ProductNm = SOURCE.ProductNm,
                       TARGET.ProductTypeId = SOURCE.ProductTypeId,
                       TARGET.ActiveInd = SOURCE.ActiveInd,
                       TARGET.SourceProductId = SOURCE.SourceProductId,
                       TARGET.SourceSystemId = SOURCE.SourceSystemId,
                       TARGET.ModifiedOn = GETDATE(),
                       TARGET.ModifiedBy = ORIGINAL_LOGIN()
        WHEN NOT MATCHED BY SOURCE AND TARGET.ProductTypeId = @CONST_ProductTypeId_SnopSupplyProduct THEN
            UPDATE SET TARGET.ActiveInd = 0;

        -- Loading UPI Sort  

        MERGE [sop].[Product] AS TARGET
        USING
        (
            SELECT DISTINCT
                   CharacteristicValue AS ProductNm,
                   @CONST_ProductTypeId_UpiSort AS ProductTypeId,
                   1 AS ActiveInd,
                   ProductDataManagementItemId AS SourceProductId,
                   0 SourceSystemId ---- Hana? What Hana?  
            FROM dbo.ItemCharacteristicDetail
            WHERE ProductDataManagementItemClassNm = 'UPI_SORT'
                  AND CharacteristicNm = 'Description'
        ) AS SOURCE
        ON SOURCE.SourceProductId = TARGET.SourceProductId
           AND SOURCE.ProductTypeId = TARGET.ProductTypeId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                ProductNm,
                ProductTypeId,
                ActiveInd,
                SourceProductId,
                SourceSystemId
            )
            VALUES
            (SOURCE.ProductNm, SOURCE.ProductTypeId, SOURCE.ActiveInd, SOURCE.SourceProductId, SOURCE.SourceSystemId)
        WHEN MATCHED THEN
            UPDATE SET TARGET.ProductNm = SOURCE.ProductNm,
                       TARGET.ProductTypeId = SOURCE.ProductTypeId,
                       TARGET.ActiveInd = SOURCE.ActiveInd,
                       TARGET.SourceProductId = SOURCE.SourceProductId,
                       TARGET.SourceSystemId = SOURCE.SourceSystemId,
                       TARGET.ModifiedOn = GETDATE(),
                       TARGET.ModifiedBy = ORIGINAL_LOGIN()
        WHEN NOT MATCHED BY SOURCE AND TARGET.ProductTypeId = @CONST_ProductTypeId_UpiSort THEN
            UPDATE SET TARGET.ActiveInd = 0;

        -- Loading Die Prep  
        MERGE [sop].[Product] AS TARGET
        USING
        (
            SELECT DISTINCT
                   ItemName ProductNm,
                   @CONST_ProductTypeId_DiePrep ProductTypeId,
                   IsActive AS ActiveInd,
                   CAST(ItemName AS VARCHAR(30)) AS SourceProductId,
                   @CONST_SourceSystemId_Svd AS SourceSystemId
            FROM dbo.Items
            WHERE ItemClass = 'DIE PREP' --AND IsActive = 1  
        ) AS SOURCE
        ON SOURCE.SourceProductId = TARGET.SourceProductId ------ ADD PRODUCT TYPE IN THE MERGE  
           AND SOURCE.ProductTypeId = TARGET.ProductTypeId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                ProductNm,
                ProductTypeId,
                ActiveInd,
                SourceProductId,
                SourceSystemId
            )
            VALUES
            (SOURCE.ProductNm, SOURCE.ProductTypeId, SOURCE.ActiveInd, SOURCE.SourceProductId, SOURCE.SourceSystemId)
        WHEN MATCHED THEN
            UPDATE SET ------ APPLY "AND" IN MATCHED Conditions  
                TARGET.ProductNm = SOURCE.ProductNm,
                TARGET.ProductTypeId = SOURCE.ProductTypeId,
                TARGET.ActiveInd = SOURCE.ActiveInd,
                TARGET.SourceProductId = SOURCE.SourceProductId,
                TARGET.SourceSystemId = SOURCE.SourceSystemId,
                TARGET.ModifiedOn = GETDATE(),
                TARGET.ModifiedBy = ORIGINAL_LOGIN()
        WHEN NOT MATCHED BY SOURCE AND TARGET.ProductTypeId = @CONST_ProductTypeId_DiePrep THEN
            UPDATE SET TARGET.ActiveInd = 0;


        --Logging End  
        EXEC sop.UspAddApplicationLog 'Database',
                                      'Info',
                                      'LoadProduct',
                                      'UspLoadProduct',
                                      'Load Product Data',
                                      'END',
                                      NULL,
                                      @BatchId;

        --Send sucess email to MPS Recon support PDL  
        EXEC [sop].[UspMPSReconSendEmail] @EmailBody = @EmailMessage,
                                          @EmailSubject = '[sop].UspLoadProduct Successful';

		--Trigger ProductAttribute update
		EXEC [sop].[UspLoadProductAttribute]

    END TRY
    BEGIN CATCH

        --Send failure email to MPS Recon support PDL   
        SET @Prog = ERROR_PROCEDURE();
        SET @EmailMessage
            = 'LoadProduct failed ' + ' at line : ' + CONVERT(VARCHAR(10), (ERROR_LINE())) + '<BR>' + 'Error in : '
              + @Prog + '<BR>' + 'Error Message : ' + ERROR_MESSAGE();

        EXEC sop.UspMPSReconSendEmail @EmailBody = @EmailMessage,
                                      @EmailSubject = '[sop].LoadProduct Failed';

        --Add Entry in Log Table  
        DECLARE @ErrorMsg VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC sop.UspAddApplicationLog 'Database',
                                      'Info',
                                      'LoadProduct',
                                      'UspLoadProduct',
                                      'Load Product Data',
                                      'ERROR',
                                      @ErrorMsg,
                                      @BatchId;

        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH;

    SET NOCOUNT OFF;
END;
