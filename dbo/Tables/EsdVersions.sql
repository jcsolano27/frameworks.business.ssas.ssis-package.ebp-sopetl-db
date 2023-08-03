CREATE TABLE [dbo].[EsdVersions] (
    [EsdVersionId]         INT            IDENTITY (1, 1) NOT NULL,
    [EsdVersionName]       VARCHAR (50)   NOT NULL,
    [Description]          VARCHAR (1000) NULL,
    [EsdBaseVersionId]     INT            NOT NULL,
    [RetainFlag]           BIT            CONSTRAINT [DF_EsdVersions_RetainFlag] DEFAULT ((0)) NOT NULL,
    [IsPOR]                BIT            CONSTRAINT [DF_EsdVersions_IsPOR] DEFAULT ((0)) NOT NULL,
    [CreatedOn]            DATETIME       CONSTRAINT [DF_EsdVersions_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]            VARCHAR (25)   CONSTRAINT [DF_EsdVersions_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [IsPrePOR]             BIT            CONSTRAINT [DF_EsdVersions_IsPrePOR] DEFAULT ((0)) NULL,
    [IsPrePORExt]          BIT            CONSTRAINT [DF_ESDVersions_IsPrePORExt] DEFAULT ((0)) NOT NULL,
    [IsCorpOp]             BIT            CONSTRAINT [DF_EsdVersions_IsCorpOp] DEFAULT ((0)) NOT NULL,
    [CopyFromEsdVersionId] INT            NULL,
    [PublishedOn]          DATETIME       NULL,
    [PublishedBy]          VARCHAR (25)   NULL,
    [RestrictHorizonInd]   BIT            DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_EsdVersions] PRIMARY KEY CLUSTERED ([EsdVersionId] ASC),
    CONSTRAINT [FK_EsdVersions_EsdBaseVersions] FOREIGN KEY ([EsdBaseVersionId]) REFERENCES [dbo].[EsdBaseVersions] ([EsdBaseVersionId])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [NonClusteredIndex-20230103-102025]
    ON [dbo].[EsdVersions]([EsdVersionName] ASC);

