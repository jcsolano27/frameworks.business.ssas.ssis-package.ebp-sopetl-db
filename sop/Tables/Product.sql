CREATE TABLE [sop].[Product] (
    [ProductId]       INT           IDENTITY (1, 1) NOT NULL,
    [ProductNm]       VARCHAR (100) NOT NULL,
    [ProductTypeId]   INT           NOT NULL,
    [ActiveInd]       BIT           CONSTRAINT [DF_Product_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceProductId] VARCHAR (30)  NOT NULL,
    [SourceSystemId]  INT           NOT NULL,
    [CreatedOn]       DATETIME      CONSTRAINT [DF_Product_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25)  CONSTRAINT [DF_Product_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]      DATETIME      CONSTRAINT [DF_Product_ModifiedOn] DEFAULT (getdate()) NOT NULL,
    [ModifiedBy]      VARCHAR (25)  CONSTRAINT [DF_Product_ModifiedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_Product] PRIMARY KEY CLUSTERED ([ProductId] ASC),
    CONSTRAINT [FK_Product_ProductType] FOREIGN KEY ([ProductTypeId]) REFERENCES [sop].[ProductType] ([ProductTypeId]),
    CONSTRAINT [FK_Product_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_Product_ProductNm]
    ON [sop].[Product]([ProductNm] ASC, [ProductTypeId] ASC);

