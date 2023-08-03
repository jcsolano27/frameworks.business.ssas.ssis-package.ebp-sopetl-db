CREATE TABLE [sop].[StgItemMapping] (
    [VersionId]       INT            NULL,
    [PublishLogId]    INT            NULL,
    [SourceItemId]    NVARCHAR (100) NULL,
    [ItemNm]          VARCHAR (MAX)  NULL,
    [ItemClassNm]     NVARCHAR (25)  NULL,
    [ItemType]        NVARCHAR (25)  NULL,
    [SdaItemNm]       NVARCHAR (50)  NULL,
    [PackageSystemId] INT            DEFAULT ([sop].[CONST_PackageSystemId_PackageSystemNm]('Dimension')) NULL,
    [SourceSystemId]  INT            DEFAULT ([sop].[CONST_SourceSystemId_SapMdg]()) NULL,
    [CreatedOnDtm]    DATETIME       DEFAULT (getdate()) NULL,
    [CreatedByNm]     [sysname]      DEFAULT (original_login()) NOT NULL
);

