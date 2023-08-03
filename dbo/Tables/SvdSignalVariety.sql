CREATE TABLE [dbo].[SvdSignalVariety] (
    [SignalVarietyId]  INT           NOT NULL,
    [SignalVarietyNm]  VARCHAR (50)  NOT NULL,
    [SignalVarietyDsc] VARCHAR (300) NULL,
    [SortOrderNbr]     SMALLINT      NOT NULL,
    [CreatedBy]        VARCHAR (25)  CONSTRAINT [DF_SvDSignalVariety_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [CreatedOn]        DATETIME      CONSTRAINT [DF_SvDSignalVariety_CreatedOn] DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_SvDSignalVariety] PRIMARY KEY CLUSTERED ([SignalVarietyId] ASC),
    CONSTRAINT [UC_SvDSignalVariety_SignalVarietyNm] UNIQUE NONCLUSTERED ([SignalVarietyNm] ASC)
);

