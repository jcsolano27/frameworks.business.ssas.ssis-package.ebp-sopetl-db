CREATE TABLE [sop].[ItemMapping] (
    [ItemMappingId]   INT           IDENTITY (1, 1) NOT NULL,
    [PublishLogId]    INT           NULL,
    [SourceVersionId] INT           NULL,
    [LrpUpiCd]        VARCHAR (100) NOT NULL,
    [MrpUpiCd]        VARCHAR (100) NOT NULL,
    [SdaUpiCd]        VARCHAR (100) NOT NULL,
    [ItemClassNm]     VARCHAR (256) NULL,
    [ItemTypeClass]   VARCHAR (20)  NULL,
    [SourceSystemId]  INT           DEFAULT ([sop].[CONST_SourceSystemId_SapMdg]()) NULL,
    [CreatedOnDtm]    DATETIME      DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]     [sysname]     DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]   DATETIME      DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]    [sysname]     DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([ItemMappingId] ASC),
    FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);

