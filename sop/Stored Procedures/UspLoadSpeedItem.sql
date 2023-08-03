CREATE PROC [sop].[UspLoadSpeedItem]
AS
----/*********************************************************************************  

----    Purpose:        This proc is used to load data from Denodo ItemDetailV10 to SVD database     
----                    Source:      [dbo].[StgItemDetail]  
----                    Destination: [dbo].[SpeedItemData]  
----    Called by:      SSIS  

----    Result sets:    None  

----    Parameters          

----    Date        User            Description  
----***************************************************************************-  
----    2023-06-09  vitorsix  Initial Release  
----*********************************************************************************/  

BEGIN
    SET NOCOUNT ON;
    SET ANSI_WARNINGS OFF;
    DECLARE @BatchId VARCHAR(100) = 'LoadSpeedItemData.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER;


    BEGIN TRY
        --Logging Start  
        EXEC sop.UspAddApplicationLog 'Database',
                                      'Info',
                                      'LoadSpeedItemData',
                                      'UspLoadSpeedItemData',
                                      'Load SpeedItemData Data',
                                      'BEGIN',
                                      NULL,
                                      @BatchId;

        -------------------------------------------------------  

        MERGE sop.SpeedItemData AS TARGET
        USING
        (
            SELECT [OwningSystemId],
                   [ItemId],
                   [ItemDsc],
                   [ItemFullDsc],
                   [CommodityCd],
                   [ItemClassCd],
                   [ItemClassNm],
                   [ItemRecommendInd],
                   [ItemRecommendId],
                   [UserItemTypeNm],
                   [EffectiveRevisionCd],
                   [CurrentRevisionCd],
                   [ItemRevisionCd],
                   [NetWeightQty],
                   [MakeBuyNm],
                   [UnitOfMeasureCd],
                   [UnitOfWeightDim],
                   [DepartmentCd],
                   [DepartmentNm],
                   [MaterialTypeCd],
                   [MaterialTypeDsc],
                   [GrossWeightQty],
                   [GlobalTradeIdentifierNbr],
                   [BusinessUnitId],
                   [BusinessUnitNm],
                   [LastClassChangeDtm],
                   [TemplateId],
                   [TemplateNm],
                   [OwningSystemLastModificationDtm],
                   [SourceSystemNm],
                   [CreateAgentId],
                   [ChangeAgentId],
                   [DeleteInd]
            FROM [SVD].[sop].[StgItemDetail]
        ) AS SOURCE
        ON SOURCE.ItemId = TARGET.ItemId
        WHEN NOT MATCHED BY TARGET THEN
            INSERT
            (
                [OwningSystemId],
                [ItemId],
                [ItemDsc],
                [ItemFullDsc],
                [CommodityCd],
                [ItemClassCd],
                [ItemClassNm],
                [ItemRecommendInd],
                [ItemRecommendId],
                [UserItemTypeNm],
                [EffectiveRevisionCd],
                [CurrentRevisionCd],
                [ItemRevisionCd],
                [NetWeightQty],
                [MakeBuyNm],
                [UnitOfMeasureCd],
                [UnitOfWeightDim],
                [DepartmentCd],
                [DepartmentNm],
                [MaterialTypeCd],
                [MaterialTypeDsc],
                [GrossWeightQty],
                [GlobalTradeIdentifierNbr],
                [BusinessUnitId],
                [BusinessUnitNm],
                [LastClassChangeDtm],
                [TemplateId],
                [TemplateNm],
                [OwningSystemLastModificationDtm],
                [SourceSystemNm],
                [CreateAgentId],
                [ChangeAgentId],
                [DeleteInd],
                [CreatedOnDtm],
                [CreatedByNm]
            )
            VALUES
            (SOURCE.OwningSystemId, SOURCE.ItemId, SOURCE.ItemDsc, SOURCE.ItemFullDsc, SOURCE.CommodityCd,
             SOURCE.ItemClassCd, SOURCE.ItemClassNm, SOURCE.ItemRecommendInd, SOURCE.ItemRecommendId,
             SOURCE.UserItemTypeNm, SOURCE.EffectiveRevisionCd, SOURCE.CurrentRevisionCd, SOURCE.ItemRevisionCd,
             SOURCE.NetWeightQty, SOURCE.MakeBuyNm, SOURCE.UnitOfMeasureCd, SOURCE.UnitOfWeightDim,
             SOURCE.DepartmentCd, SOURCE.DepartmentNm, SOURCE.MaterialTypeCd, SOURCE.MaterialTypeDsc,
             SOURCE.GrossWeightQty, SOURCE.GlobalTradeIdentifierNbr, SOURCE.BusinessUnitId, SOURCE.BusinessUnitNm,
             SOURCE.LastClassChangeDtm, SOURCE.TemplateId, SOURCE.TemplateNm, SOURCE.OwningSystemLastModificationDtm,
             SOURCE.SourceSystemNm, SOURCE.CreateAgentId, SOURCE.ChangeAgentId, SOURCE.DeleteInd, GETDATE(),
             USER_NAME())
        WHEN NOT MATCHED BY SOURCE THEN
            UPDATE SET TARGET.DeleteInd = 1
        WHEN MATCHED THEN
            UPDATE SET TARGET.OwningSystemId = SOURCE.[OwningSystemId],
                       --,TARGET.[ItemId] = SOURCE.[ItemId]  
                       TARGET.ItemDsc = SOURCE.[ItemDsc],
                       TARGET.ItemFullDsc = SOURCE.[ItemFullDsc],
                       TARGET.CommodityCd = SOURCE.[CommodityCd],
                       TARGET.ItemClassCd = SOURCE.[ItemClassCd],
                       TARGET.ItemClassNm = SOURCE.[ItemClassNm],
                       TARGET.ItemRecommendInd = SOURCE.[ItemRecommendInd],
                       TARGET.ItemRecommendId = SOURCE.[ItemRecommendId],
                       TARGET.UserItemTypeNm = SOURCE.[UserItemTypeNm],
                       TARGET.EffectiveRevisionCd = SOURCE.[EffectiveRevisionCd],
                       TARGET.CurrentRevisionCd = SOURCE.[CurrentRevisionCd],
                       TARGET.ItemRevisionCd = SOURCE.[ItemRevisionCd],
                       TARGET.NetWeightQty = SOURCE.[NetWeightQty],
                       TARGET.MakeBuyNm = SOURCE.[MakeBuyNm],
                       TARGET.UnitOfMeasureCd = SOURCE.[UnitOfMeasureCd],
                       TARGET.UnitOfWeightDim = SOURCE.[UnitOfWeightDim],
                       TARGET.DepartmentCd = SOURCE.[DepartmentCd],
                       TARGET.DepartmentNm = SOURCE.[DepartmentNm],
                       TARGET.MaterialTypeCd = SOURCE.[MaterialTypeCd],
                       TARGET.MaterialTypeDsc = SOURCE.[MaterialTypeDsc],
                       TARGET.GrossWeightQty = SOURCE.[GrossWeightQty],
                       TARGET.GlobalTradeIdentifierNbr = SOURCE.[GlobalTradeIdentifierNbr],
                       TARGET.BusinessUnitId = SOURCE.[BusinessUnitId],
                       TARGET.BusinessUnitNm = SOURCE.[BusinessUnitNm],
                       TARGET.LastClassChangeDtm = SOURCE.[LastClassChangeDtm],
                       TARGET.TemplateId = SOURCE.[TemplateId],
                       TARGET.TemplateNm = SOURCE.[TemplateNm],
                       TARGET.OwningSystemLastModificationDtm = SOURCE.[OwningSystemLastModificationDtm],
                       TARGET.SourceSystemNm = SOURCE.[SourceSystemNm],
                       TARGET.CreateAgentId = SOURCE.[CreateAgentId],
                       TARGET.ChangeAgentId = SOURCE.[ChangeAgentId],
                       TARGET.DeleteInd = SOURCE.[DeleteInd],
                       TARGET.ModifiedOnDtm = GETDATE(),
                       TARGET.ModifiedByNm = USER_NAME();

        --Logging End  
        EXEC dbo.UspAddApplicationLog 'Database',
                                      'Info',
                                      'LoadSpeedItemData',
                                      'UspLoadSpeedItemData',
                                      'Load SpeedItemData Data',
                                      'END',
                                      NULL,
                                      @BatchId;


    END TRY
    BEGIN CATCH

        --Add Entry in Log Table  
        DECLARE @ErrorMsg VARCHAR(MAX) = ERROR_MESSAGE();
        EXEC sop.UspAddApplicationLog 'Database',
                                      'Info',
                                      'LoadSpeedItemData',
                                      'UspLoadSpeedItemData',
                                      'Load SpeedItemData Data',
                                      'ERROR',
                                      @ErrorMsg,
                                      @BatchId;

        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH;

    SET NOCOUNT OFF;
    SET ANSI_WARNINGS ON;
END;