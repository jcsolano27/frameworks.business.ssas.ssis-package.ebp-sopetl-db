CREATE TABLE [dbo].[StgHdmrSnapshot] (
    [HdmrVersionId]  INT           NULL,
    [HdmrVersionNm]  VARCHAR (MAX) NULL,
    [HdmrVersionDsc] VARCHAR (MAX) NULL,
    [SnapshotId]     INT           NULL,
    [SnapshotNm]     VARCHAR (MAX) NULL,
    [SnapshotDsc]    VARCHAR (MAX) NULL,
    [PlanningCycle]  VARCHAR (10)  NULL,
    [SnapshotType]   VARCHAR (50)  NULL,
    [ProcessStatus]  VARCHAR (50)  NULL,
    [PublishTs]      DATETIME      NULL,
    [CreatedOn]      DATETIME      DEFAULT (getdate()) NULL,
    [CreatedBy]      VARCHAR (25)  DEFAULT (original_login()) NULL
);

