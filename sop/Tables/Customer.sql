CREATE TABLE [sop].[Customer] (
    [CustomerId]       INT           NOT NULL,
    [CustomerNm]       VARCHAR (50)  NOT NULL,
    [CustomerDsc]      VARCHAR (100) NULL,
    [HostedRegionCd]   VARCHAR (50)  NOT NULL,
    [CustomerTypeCd]   VARCHAR (50)  NOT NULL,
    [ActiveInd]        BIT           CONSTRAINT [DF_Customer_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceCustomerId] INT           NOT NULL,
    [SourceSystemId]   INT           NOT NULL,
    [CreatedOnDtm]     DATETIME      CONSTRAINT [DF_Customer_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]      VARCHAR (25)  CONSTRAINT [DF_Customer_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME      CONSTRAINT [DF_Customer_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]     VARCHAR (25)  CONSTRAINT [DF_Customer_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED ([CustomerId] ASC),
    CONSTRAINT [FK_Customer_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);


GO
CREATE NONCLUSTERED INDEX [UC_Customer_CustomerNm]
    ON [sop].[Customer]([CustomerNm] ASC);

