CREATE TABLE [dbo].[SvdReportProfile] (
    [ProfileId]    INT           NOT NULL,
    [ProfileNm]    VARCHAR (50)  NOT NULL,
    [ProfileDsc]   VARCHAR (300) NULL,
    [SortOrderNbr] SMALLINT      NULL,
    [CreatedBy]    VARCHAR (25)  CONSTRAINT [DF_SvDReportProfile_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [CreatedOn]    DATETIME      CONSTRAINT [DF_SvDReportProfile_CreatedOn] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_SvDReportProfile] PRIMARY KEY CLUSTERED ([ProfileId] ASC)
);

