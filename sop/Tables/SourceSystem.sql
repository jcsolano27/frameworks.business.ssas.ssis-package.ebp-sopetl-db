CREATE TABLE [sop].[SourceSystem] (
    [SourceSystemId]  INT           NOT NULL,
    [SourceSystemNm]  VARCHAR (25)  NOT NULL,
    [SourceSystemDsc] VARCHAR (250) NULL,
    [CreatedOnDtm]    DATETIME      CONSTRAINT [DF_SourceSystem_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]     VARCHAR (25)  CONSTRAINT [DF_SourceSystem_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]   DATETIME      CONSTRAINT [DF_SourceSystem_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]    VARCHAR (25)  CONSTRAINT [DF_SourceSystem_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SourceSystem] PRIMARY KEY CLUSTERED ([SourceSystemId] ASC)
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_SourceSystem_SourceSystemNm]
    ON [sop].[SourceSystem]([SourceSystemNm] ASC);

