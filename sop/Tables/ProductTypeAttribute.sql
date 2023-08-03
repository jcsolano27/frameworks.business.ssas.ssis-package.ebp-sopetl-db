CREATE TABLE [sop].[ProductTypeAttribute] (
    [ProductTypeId]  INT          NOT NULL,
    [AttributeId]    INT          NOT NULL,
    [DerivedInd]     BIT          CONSTRAINT [DF_ProductTypeAttribute_DerivedInd] DEFAULT ((0)) NOT NULL,
    [ActiveInd]      BIT          CONSTRAINT [DF_ProductTypeAttribute_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId] INT          NOT NULL,
    [CreatedOnDtm]   DATETIME     CONSTRAINT [DF_ProductTypeAttribute_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]    VARCHAR (25) CONSTRAINT [DF_ProductTypeAttribute_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]  DATETIME     CONSTRAINT [DF_ProductTypeAttribute_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]   VARCHAR (25) CONSTRAINT [DF_ProductTypeAttribute_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ProductTypeAttribute] PRIMARY KEY CLUSTERED ([ProductTypeId] ASC, [AttributeId] ASC),
    CONSTRAINT [FK_ProductTypeAttribute_Attribute] FOREIGN KEY ([AttributeId]) REFERENCES [sop].[Attribute] ([AttributeId]),
    CONSTRAINT [FK_ProductTypeAttribute_ProductType] FOREIGN KEY ([ProductTypeId]) REFERENCES [sop].[ProductType] ([ProductTypeId]),
    CONSTRAINT [FK_ProductTypeAttribute_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);

