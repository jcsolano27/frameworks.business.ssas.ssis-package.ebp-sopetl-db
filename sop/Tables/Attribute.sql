CREATE TABLE [sop].[Attribute] (
    [AttributeId]       INT           IDENTITY (1, 1) NOT NULL,
    [AttributeNm]       VARCHAR (100) NOT NULL,
    [AttributeCommonNm] VARCHAR (100) NOT NULL,
    [SourceAttributeNm] VARCHAR (100) NOT NULL,
    [ActiveInd]         BIT           CONSTRAINT [DF_Attribute_ActiveInd] DEFAULT ((0)) NOT NULL,
    [SourceSystemId]    INT           CONSTRAINT [DF_Attribute_SourceSystemId] DEFAULT ((0)) NOT NULL,
    [CreatedOn]         DATETIME      CONSTRAINT [DF_Attribute_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]         VARCHAR (25)  CONSTRAINT [DF_Attribute_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]        DATETIME      CONSTRAINT [DF_Attribute_ModifiedOn] DEFAULT (getdate()) NOT NULL,
    [ModifiedBy]        VARCHAR (25)  CONSTRAINT [DF_Attribute_ModifiedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_Attribute] PRIMARY KEY CLUSTERED ([AttributeId] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_Attribute_AttributeNm]
    ON [sop].[Attribute]([AttributeNm] ASC);

