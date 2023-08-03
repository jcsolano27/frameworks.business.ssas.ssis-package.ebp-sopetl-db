CREATE TABLE [dbo].[StgSvdLoadStatus] (
    [StgSvdLoadStatus]       INT            IDENTITY (0, 1) NOT NULL,
    [LoadSourceNm]           VARCHAR (1000) NULL,
    [SvdSourceApplicationId] VARCHAR (1000) NULL,
    [LastModifiedDate]       DATETIME       NULL,
    [VersionNm]              VARCHAR (10)   NULL,
    [VersionId]              INT            NULL,
    PRIMARY KEY CLUSTERED ([StgSvdLoadStatus] ASC)
);

