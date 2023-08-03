CREATE TABLE [dbo].[GuiUIDataLoadRequest] (
    [DataLoadRequestId] INT          NOT NULL,
    [EsdVersionId]      INT          NOT NULL,
    [TableLoadGroupId]  INT          NOT NULL,
    [BatchRunId]        INT          NOT NULL,
    [CreatedOn]         DATETIME     CONSTRAINT [DF_UIDataLoadRequest_CreatedOn] DEFAULT (getdate()) NULL,
    [CreatedBy]         VARCHAR (50) CONSTRAINT [DF_UIDataLoadRequest_CreatedBy] DEFAULT (original_login()) NULL,
    CONSTRAINT [PK_UIDataLoadRequest] PRIMARY KEY CLUSTERED ([DataLoadRequestId] ASC, [EsdVersionId] ASC, [TableLoadGroupId] ASC, [BatchRunId] ASC)
);

