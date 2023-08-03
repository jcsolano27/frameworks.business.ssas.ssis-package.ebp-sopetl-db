CREATE TABLE [dbo].[SDRAVersion] (
    [VersionId] INT           NOT NULL,
    [VersionNm] NVARCHAR (50) NOT NULL,
    [UpdatedOn] DATETIME      CONSTRAINT [DF_SDRAVersion_UpdatedOn] DEFAULT (getdate()) NOT NULL,
    [UpdatedBy] NVARCHAR (50) CONSTRAINT [DF_SDRAVersion_UpdatedBy] DEFAULT (user_name()) NOT NULL
);

