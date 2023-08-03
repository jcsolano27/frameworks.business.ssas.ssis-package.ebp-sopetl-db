CREATE TABLE [sop].[ProductAttribute] (
    [ProductId]      INT           NOT NULL,
    [AttributeId]    INT           NOT NULL,
    [AttributeVal]   VARCHAR (500) NOT NULL,
    [ActiveInd]      BIT           CONSTRAINT [DF_ProductAttribute_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId] INT           CONSTRAINT [DF_ProductAttribute_SourceSystemId] DEFAULT ((0)) NOT NULL,
    [CreatedOn]      DATETIME      CONSTRAINT [DF_ProductAttribute_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]      VARCHAR (25)  CONSTRAINT [DF_ProductAttribute_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]     DATETIME      CONSTRAINT [DF_ProductAttribute_ModifiedOn] DEFAULT (getdate()) NOT NULL,
    [ModifiedBy]     VARCHAR (25)  CONSTRAINT [DF_ProductAttribute_ModifiedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ProductAttribute] PRIMARY KEY CLUSTERED ([ProductId] ASC, [AttributeId] ASC),
    CONSTRAINT [FK_ProductAttribute_Attribute] FOREIGN KEY ([AttributeId]) REFERENCES [sop].[Attribute] ([AttributeId]),
    CONSTRAINT [FK_ProductAttribute_Product] FOREIGN KEY ([ProductId]) REFERENCES [sop].[Product] ([ProductId])
);

