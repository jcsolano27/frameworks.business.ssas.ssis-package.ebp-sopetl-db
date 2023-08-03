CREATE TABLE [dbo].[SvdLoadStatus] (
    [SvdLoadStatusId]        INT            IDENTITY (0, 1) NOT NULL,
    [SourceNm]               VARCHAR (1000) NULL,
    [LastLoadDate]           DATETIME       NULL,
    [LastModifiedDate]       DATETIME       NULL,
    [IsLoad]                 BIT            NOT NULL,
    [IsForceLoad]            BIT            NOT NULL,
    [CreatedOn]              DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25)   DEFAULT (original_login()) NOT NULL,
    [VersionsId]             VARCHAR (1000) NULL,
    [SvdSourceApplicationId] INT            NULL,
    [PackageNm]              VARCHAR (100)  NULL,
    [VersionType]            VARCHAR (1000) NULL,
    PRIMARY KEY CLUSTERED ([SvdLoadStatusId] ASC)
);

