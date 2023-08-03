CREATE TABLE [dbo].[StgProfitCenterHierarchy] (
    [ProfitCenterHierarchyId] NVARCHAR (100) NULL,
    [ProfitCenterCd]          INT            NOT NULL,
    [ProfitCenterNm]          NVARCHAR (100) NOT NULL,
    [DivisionCd]              NVARCHAR (100) NULL,
    [GroupCd]                 NVARCHAR (100) NULL,
    [SuperGroupCd]            NVARCHAR (100) NULL,
    [DivisionNm]              NVARCHAR (100) NULL,
    [GroupNm]                 NVARCHAR (100) NULL,
    [SuperGroupNm]            NVARCHAR (100) NULL,
    [ValidFromDt]             NVARCHAR (50)  NULL,
    [ValidToDt]               NVARCHAR (50)  NULL,
    [ValidInd]                NVARCHAR (2)   NULL,
    [CreatedOn]               DATETIME       CONSTRAINT [DF_StgProfitCenterHierarchy_CreatedOn] DEFAULT (getdate()) NULL,
    [ProfitCenterDsc]         NVARCHAR (40)  NULL
);

