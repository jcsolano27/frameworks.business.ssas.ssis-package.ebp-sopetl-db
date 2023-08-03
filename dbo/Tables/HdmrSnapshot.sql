CREATE TABLE [dbo].[HdmrSnapshot] (
    [SourceVersionId] INT           NOT NULL,
    [PlanningMonth]   INT           NULL,
    [SourceVersionNm] VARCHAR (MAX) NULL,
    [HdmrVersionNm]   VARCHAR (MAX) NULL,
    [SnapshotType]    VARCHAR (50)  NULL,
    [CreatedOn]       DATETIME      DEFAULT (getdate()) NULL,
    [CreatedBy]       VARCHAR (25)  DEFAULT (original_login()) NULL,
    PRIMARY KEY CLUSTERED ([SourceVersionId] ASC)
);

