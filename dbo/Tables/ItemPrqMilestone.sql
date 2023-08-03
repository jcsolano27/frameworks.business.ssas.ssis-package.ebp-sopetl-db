CREATE TABLE [dbo].[ItemPrqMilestone] (
    [BulkId]        BIGINT         NULL,
    [RowId]         INT            NULL,
    [InsDtm]        DATETIME       NULL,
    [InstcNm]       NVARCHAR (255) NULL,
    [SpeedId]       INT            NOT NULL,
    [Project]       NVARCHAR (255) NULL,
    [MilestoneUid]  NVARCHAR (100) NULL,
    [Milestone]     NVARCHAR (100) NULL,
    [MilestoneBase] NVARCHAR (255) NULL,
    [PlcOrder]      INT            NULL,
    [Importance]    INT            NULL,
    [Por]           DATETIME       NULL,
    [NpiFlag]       NVARCHAR (6)   NULL,
    [CreatedOn]     DATETIME       CONSTRAINT [DF_ItemPrqMilestones_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]     VARCHAR (25)   CONSTRAINT [DF_ItemPrqMilestones_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]    DATETIME       CONSTRAINT [DF_ItemPrqMilestoness_ModifiedOn] DEFAULT (getdate()) NULL,
    [ModifiedBy]    VARCHAR (25)   CONSTRAINT [DF_ItemPrqMilestones_ModifiedBy] DEFAULT (user_name()) NULL,
    PRIMARY KEY CLUSTERED ([SpeedId] ASC)
);

