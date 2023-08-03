CREATE TABLE [dbo].[SvdOutput] (
    [SvdSourceVersionId]  INT          NOT NULL,
    [ProfitCenterCd]      INT          NOT NULL,
    [SnOPDemandProductId] INT          NOT NULL,
    [BusinessGroupingId]  INT          NOT NULL,
    [ParameterId]         INT          NOT NULL,
    [FiscalCalendarId]    INT          NOT NULL,
    [QuarterNbr]          SMALLINT     NOT NULL,
    [Quantity]            FLOAT (53)   NULL,
    [CreatedOn]           DATETIME     CONSTRAINT [DF_SvdOutput_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           VARCHAR (25) CONSTRAINT [DF_SvdOutput_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SvdOutput] PRIMARY KEY CLUSTERED ([ProfitCenterCd] ASC, [SnOPDemandProductId] ASC, [BusinessGroupingId] ASC, [SvdSourceVersionId] ASC, [ParameterId] ASC, [QuarterNbr] ASC, [FiscalCalendarId] ASC),
    CONSTRAINT [FK_BusinessGrouping_SvdOutput] FOREIGN KEY ([BusinessGroupingId]) REFERENCES [dbo].[BusinessGrouping] ([BusinessGroupingId]),
    CONSTRAINT [FK_FiscalCalendar_SvdOutput] FOREIGN KEY ([FiscalCalendarId]) REFERENCES [dbo].[SopFiscalCalendar] ([FiscalCalendarIdentifier]),
    CONSTRAINT [FK_ProfitCenter_SvdOutput] FOREIGN KEY ([ProfitCenterCd]) REFERENCES [dbo].[ProfitCenterHierarchy] ([ProfitCenterCd]),
    CONSTRAINT [FK_SnopDemandProduct_SvdOutput] FOREIGN KEY ([SnOPDemandProductId]) REFERENCES [dbo].[SnOPDemandProductHierarchy] ([SnOPDemandProductId]),
    CONSTRAINT [FK_SvdParameters_SvdOutput] FOREIGN KEY ([ParameterId]) REFERENCES [dbo].[Parameters] ([ParameterId]),
    CONSTRAINT [FK_SvdRelativeQuarter_SvdOutput] FOREIGN KEY ([QuarterNbr]) REFERENCES [dbo].[SvdRelativeQuarter] ([QuarterNbr]),
    CONSTRAINT [FK_SvdSourceVersion_SvdOutput] FOREIGN KEY ([SvdSourceVersionId]) REFERENCES [dbo].[SvdSourceVersion] ([SvdSourceVersionId])
);

