CREATE TABLE [dbo].[EsdVersionActionLog] (
    [EsdVersionId]     INT          NOT NULL,
    [EsdVersionAction] VARCHAR (25) NOT NULL,
    [CreatedOn]        DATETIME     CONSTRAINT [DF_EsdVersionActionLog_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]        VARCHAR (25) CONSTRAINT [DF_EsdVersionActionLog_CreatedBy] DEFAULT (original_login()) NOT NULL
);

