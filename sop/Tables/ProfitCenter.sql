CREATE TABLE [sop].[ProfitCenter] (
    [ProfitCenterCd]       INT           NOT NULL,
    [ProfitCenterNm]       VARCHAR (100) NOT NULL,
    [DivisionNm]           VARCHAR (100) NULL,
    [GroupNm]              VARCHAR (100) NULL,
    [SuperGroupNm]         VARCHAR (100) NULL,
    [DivisionDsc]          VARCHAR (100) NULL,
    [GroupDsc]             VARCHAR (100) NULL,
    [SuperGroupDsc]        VARCHAR (100) NULL,
    [ActiveInd]            BIT           CONSTRAINT [DF_ProfitCenter_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceProfitCenterId] INT           NOT NULL,
    [SourceSystemId]       INT           NOT NULL,
    [CreatedOnDtm]         DATETIME      CONSTRAINT [DF_ProfitCenter_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]          VARCHAR (25)  CONSTRAINT [DF_ProfitCenter_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]        DATETIME      CONSTRAINT [DF_ProfitCenter_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]         VARCHAR (25)  CONSTRAINT [DF_ProfitCenter_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ProfitCenter] PRIMARY KEY CLUSTERED ([ProfitCenterCd] ASC),
    CONSTRAINT [FK_ProfitCenter_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);

