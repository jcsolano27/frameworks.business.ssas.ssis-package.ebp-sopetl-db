CREATE TABLE [dbo].[StgHdmrTargetSupply] (
    [SnapshotId]           INT           NULL,
    [ProductNodeId]        INT           NULL,
    [ParameterTypeNm]      VARCHAR (100) NULL,
    [FiscalYearQuarterNbr] INT           NULL,
    [ParameterQty]         FLOAT (53)    NULL,
    [CreatedOn]            DATETIME      DEFAULT (getdate()) NULL,
    [CreatedBy]            VARCHAR (25)  DEFAULT (original_login()) NULL
);

