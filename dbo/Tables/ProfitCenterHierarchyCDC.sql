CREATE TABLE [dbo].[ProfitCenterHierarchyCDC] (
    [ProfitCenterHierarchyId] INT           NULL,
    [ProfitCenterCd]          INT           NOT NULL,
    [ProfitCenterNm]          VARCHAR (100) NOT NULL,
    [IsActive]                BIT           NOT NULL,
    [DivisionDsc]             VARCHAR (100) NULL,
    [GroupDsc]                VARCHAR (100) NULL,
    [SuperGroupDsc]           VARCHAR (100) NULL,
    [CreatedOn]               DATETIME      NOT NULL,
    [CreatedBy]               VARCHAR (25)  NOT NULL,
    [DivisionNm]              VARCHAR (100) NULL,
    [GroupNm]                 VARCHAR (100) NULL,
    [SuperGroupNm]            VARCHAR (100) NULL,
    [OperationDsc]            VARCHAR (50)  NULL,
    [CDCDate]                 DATETIME      NOT NULL,
    CONSTRAINT [PK_ProfitCenterHierarchyCDC] PRIMARY KEY CLUSTERED ([ProfitCenterCd] ASC, [CDCDate] ASC)
);

