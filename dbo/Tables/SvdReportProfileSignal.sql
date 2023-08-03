CREATE TABLE [dbo].[SvdReportProfileSignal] (
    [ProfileId]       INT          NOT NULL,
    [IntelQuarterNbr] TINYINT      NOT NULL,
    [SignalId]        INT          NOT NULL,
    [SignalVarietyId] INT          NOT NULL,
    [QuarterNbr]      SMALLINT     NOT NULL,
    [ParameterId]     INT          NOT NULL,
    [IsActive]        BIT          NOT NULL,
    [IsAdj]           BIT          NOT NULL,
    [CreatedBy]       VARCHAR (25) CONSTRAINT [DF_SvDReportProfileSignal_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [CreatedOn]       DATETIME     CONSTRAINT [DF_SvDReportProfileSignal_CreatedOn] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_SvDReportProfileSignal] PRIMARY KEY CLUSTERED ([ProfileId] ASC, [IntelQuarterNbr] ASC, [SignalId] ASC, [SignalVarietyId] ASC, [QuarterNbr] ASC, [ParameterId] ASC),
    CONSTRAINT [FK_SvDReportProfileSignal_Parameter] FOREIGN KEY ([ParameterId]) REFERENCES [dbo].[Parameters] ([ParameterId]),
    CONSTRAINT [FK_SvDReportProfileSignal_SvDRelativeQuarter] FOREIGN KEY ([QuarterNbr]) REFERENCES [dbo].[SvdRelativeQuarter] ([QuarterNbr]),
    CONSTRAINT [FK_SvDReportProfileSignal_SvDReportProfile] FOREIGN KEY ([ProfileId]) REFERENCES [dbo].[SvdReportProfile] ([ProfileId]),
    CONSTRAINT [FK_SvDReportProfileSignal_SvDSignal] FOREIGN KEY ([SignalId]) REFERENCES [dbo].[SvdSignal] ([SignalId]),
    CONSTRAINT [FK_SvDReportProfileSignal_SvDSignalVariety] FOREIGN KEY ([SignalVarietyId]) REFERENCES [dbo].[SvdSignalVariety] ([SignalVarietyId])
);

