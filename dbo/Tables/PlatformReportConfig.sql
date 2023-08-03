CREATE TABLE [dbo].[PlatformReportConfig] (
    [BusinessEntityNm]      VARCHAR (50)  NOT NULL,
    [ReportSectionCd]       VARCHAR (10)  NOT NULL,
    [ReportSectionGroupNbr] INT           NOT NULL,
    [AttributeNm]           VARCHAR (100) NOT NULL,
    [AttributeValue]        VARCHAR (100) NOT NULL,
    [CreatedBy]             VARCHAR (25)  DEFAULT (suser_sname()) NOT NULL,
    [CreatedOn]             DATETIME      DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_PlatforReportConfig] PRIMARY KEY CLUSTERED ([BusinessEntityNm] ASC, [ReportSectionCd] ASC, [ReportSectionGroupNbr] ASC, [AttributeNm] ASC, [AttributeValue] ASC)
);

