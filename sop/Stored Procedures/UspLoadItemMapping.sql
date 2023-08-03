----/********************************************************************************  
----  
----    Purpose:        This proc is used to load [sop].[ItemMapping] data  
----                    Source:      [sop].[StgItemMapping]  
----                    Destination: [sop].[ItemMapping]  
----    Called by:      SSIS  
----  
----    Result sets:    None  
----  
----    Date   User            Description  
----*********************************************************************************  
---- 2023-06-27  caiosanx  Initial Release  
----*********************************************************************************/  

CREATE PROC [sop].[UspLoadItemMapping]
(@VersionId INT)

WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

MERGE sop.ItemMapping T
USING
(
    SELECT VersionId SourceVersionId,
           PublishLogId,
           SourceItemId LrpUpiCd,
           ItemNm MrpUpiCd,
           ItemClassNm,
           ItemType ItemTypeClass,
           SdaItemNm SdaUpiCd,
           SourceSystemId
    FROM sop.StgItemMapping
    WHERE VersionId = 13722
) S
ON S.SourceVersionId = T.SourceVersionId
   AND S.MrpUpiCd = T.MrpUpiCd
   AND S.SdaUpiCd = T.SdaUpiCd
   AND S.LrpUpiCd = T.LrpUpiCd
   AND S.ItemClassNm = T.ItemClassNm
   AND S.ItemTypeClass = T.ItemTypeClass
   AND S.SourceSystemId = T.SourceSystemId
   AND S.PublishLogId = T.PublishLogId
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        SourceVersionId,
        PublishLogId,
        LrpUpiCd,
        MrpUpiCd,
        ItemClassNm,
        ItemTypeClass,
        SdaUpiCd,
        SourceSystemId,
        CreatedOnDtm,
        CreatedByNm,
        ModifiedOnDtm,
        ModifiedByNm
    )
    VALUES
    (S.SourceVersionId, S.PublishLogId, S.LrpUpiCd, S.MrpUpiCd, S.ItemClassNm, S.ItemTypeClass, S.SdaUpiCd,
     S.SourceSystemId, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
WHEN NOT MATCHED BY SOURCE AND T.SourceVersionId = @VersionId THEN
    DELETE;