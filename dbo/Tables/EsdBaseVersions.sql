CREATE TABLE [dbo].[EsdBaseVersions] (
    [EsdBaseVersionId]   INT          IDENTITY (18, 1) NOT NULL,
    [EsdBaseVersionName] VARCHAR (50) NOT NULL,
    [PlanningMonthId]    INT          NOT NULL,
    [CreatedOn]          DATETIME     CONSTRAINT [DF_EsdBaseVersions_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]          VARCHAR (25) CONSTRAINT [DF_EsdBaseVersions_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_EsdBaseVersions] PRIMARY KEY CLUSTERED ([EsdBaseVersionId] ASC)
);

