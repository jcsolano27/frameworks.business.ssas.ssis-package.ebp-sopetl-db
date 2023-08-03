CREATE TABLE [dbo].[SvdSignal] (
    [SignalId]     INT           NOT NULL,
    [SignalNm]     VARCHAR (50)  NOT NULL,
    [SignalDsc]    VARCHAR (300) NULL,
    [SortOrderNbr] SMALLINT      NOT NULL,
    [CreatedBy]    VARCHAR (25)  CONSTRAINT [DF_SvDSignal_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [CreatedOn]    DATETIME      CONSTRAINT [DF_SvDSignal_CreatedOn] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_SvdSignal] PRIMARY KEY CLUSTERED ([SignalId] ASC),
    CONSTRAINT [UC_SvDSignal_SignalNm] UNIQUE NONCLUSTERED ([SignalNm] ASC)
);

