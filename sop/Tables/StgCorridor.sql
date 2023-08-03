CREATE TABLE [sop].[StgCorridor] (
    [PublishLogId]      INT              NULL,
    [ParameterTypeName] NVARCHAR (255)   NULL,
    [FabProcess]        NVARCHAR (100)   NULL,
    [LocationName]      NVARCHAR (50)    NULL,
    [Owner]             NVARCHAR (3)     NULL,
    [BucketType]        NVARCHAR (5)     NULL,
    [Bucket]            NVARCHAR (10)    NULL,
    [Quantity]          DECIMAL (38, 10) NULL,
    [PackageSystemId]   INT              DEFAULT ([sop].[CONST_PackageSystemId_PackageSystemNm]('Dimension')) NULL,
    [SourceSystemId]    INT              DEFAULT ([sop].[CONST_SourceSystemId_SapMdg]()) NULL,
    [CreatedOnDtm]      DATETIME         DEFAULT (getdate()) NULL,
    [CreatedByNm]       [sysname]        DEFAULT (original_login()) NOT NULL
);

