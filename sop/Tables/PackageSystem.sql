CREATE TABLE [sop].[PackageSystem] (
    [PackageSystemId] INT          NOT NULL,
    [PackageSystemNm] VARCHAR (25) NOT NULL,
    [CreatedOnDtm]    DATETIME     CONSTRAINT [DF_PackageSystem_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]     VARCHAR (25) CONSTRAINT [DF_PackageSystem_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_PackageSystem] PRIMARY KEY CLUSTERED ([PackageSystemId] ASC)
);

