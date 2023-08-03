CREATE TABLE [sop].[ProductType] (
    [ProductTypeId]  INT           IDENTITY (1, 1) NOT NULL,
    [ProductTypeNm]  VARCHAR (50)  NOT NULL,
    [ProductTypeDsc] VARCHAR (100) NULL,
    [ActiveInd]      BIT           CONSTRAINT [DF_ProductType_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId] INT           NOT NULL,
    [CreatedOnDtm]   DATETIME      CONSTRAINT [DF_ProductType_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]    VARCHAR (25)  CONSTRAINT [DF_ProductType_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]  DATETIME      CONSTRAINT [DF_ProductType_ModifiedOn] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]   VARCHAR (25)  CONSTRAINT [DF_ProductType_ModifiedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ProductType] PRIMARY KEY CLUSTERED ([ProductTypeId] ASC),
    CONSTRAINT [FK_ProductType_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_ProductTypeNm]
    ON [sop].[ProductType]([ProductTypeNm] ASC);

