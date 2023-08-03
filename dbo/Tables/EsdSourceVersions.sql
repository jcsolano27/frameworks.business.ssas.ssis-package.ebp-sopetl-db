CREATE TABLE [dbo].[EsdSourceVersions] (
    [EsdVersionId]          INT           NOT NULL,
    [SourceApplicationId]   INT           NOT NULL,
    [SourceVersionId]       INT           NOT NULL,
    [HorizonStartYearWw]    INT           NULL,
    [HorizonEndYearww]      INT           NULL,
    [CreatedOn]             DATETIME      CONSTRAINT [DF_EsdSourceVersions_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25)  CONSTRAINT [DF_EsdSourceVersions_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [SourceVersionName]     VARCHAR (100) NULL,
    [SourceVersionDivision] VARCHAR (25)  NULL,
    [LoadedOn]              DATETIME      NULL,
    CONSTRAINT [PK_EsdSourceVersions] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC, [SourceApplicationId] ASC, [SourceVersionId] ASC),
    CONSTRAINT [FK_EsdSourceVersions_EsdVersions] FOREIGN KEY ([EsdVersionId]) REFERENCES [dbo].[EsdVersions] ([EsdVersionId])
);

