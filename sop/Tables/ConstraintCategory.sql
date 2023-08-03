CREATE TABLE [sop].[ConstraintCategory] (
    [ConstraintCategoryId]  INT           IDENTITY (1, 1) NOT NULL,
    [ConstraintCategoryNm]  VARCHAR (50)  NOT NULL,
    [ConstraintCategoryDsc] VARCHAR (250) NULL,
    [ActiveInd]             BIT           CONSTRAINT [DF_ConstraintCategory_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId]        INT           NOT NULL,
    [CreatedOnDtm]          DATETIME      CONSTRAINT [DF_ConstraintCategory_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]           VARCHAR (25)  CONSTRAINT [DF_ConstraintCategory_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]         DATETIME      CONSTRAINT [DF_ConstraintCategory_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]          VARCHAR (25)  CONSTRAINT [DF_ConstraintCategory_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ConstraintCategory] PRIMARY KEY CLUSTERED ([ConstraintCategoryId] ASC),
    CONSTRAINT [FK_ConstraintCategory_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);

