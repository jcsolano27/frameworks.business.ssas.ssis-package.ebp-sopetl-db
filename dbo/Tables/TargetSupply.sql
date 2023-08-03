CREATE TABLE [dbo].[TargetSupply] (
    [PlanningMonth]          INT          NOT NULL,
    [SourceApplicationId]    INT          NOT NULL,
    [SvdSourceApplicationId] INT          NOT NULL,
    [SourceVersionId]        INT          NOT NULL,
    [SupplyParameterId]      INT          NOT NULL,
    [SnOPDemandProductId]    INT          NOT NULL,
    [YearQq]                 INT          NOT NULL,
    [Supply]                 FLOAT (53)   NULL,
    [CreatedOn]              DATETIME     CONSTRAINT [DF_SvdHdmrSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25) CONSTRAINT [DF_SvdHdmrSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_TargetSupply] PRIMARY KEY CLUSTERED ([PlanningMonth] ASC, [SupplyParameterId] ASC, [SourceApplicationId] ASC, [SvdSourceApplicationId] ASC, [SourceVersionId] ASC, [SnOPDemandProductId] ASC, [YearQq] ASC)
);

