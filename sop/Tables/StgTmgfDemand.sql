CREATE TABLE [sop].[StgTmgfDemand] (
    [PlanningMonthNbr] INT              NULL,
    [PlanVersionId]    INT              NULL,
    [ProductId]        INT              NULL,
    [ProfitCenterCd]   INT              NULL,
    [KeyFigureId]      INT              NULL,
    [TimePeriodId]     INT              NULL,
    [Quantity]         DECIMAL (38, 10) NULL,
    [SourceSystemId]   INT              NULL,
    [CreatedOnDtm]     DATETIME         CONSTRAINT [DF_StgTmgfDemand_CreatedOnDtm] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedByNm]      VARCHAR (25)     CONSTRAINT [DF_StgTmgfDemand_CreatedbyNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]    DATETIME         CONSTRAINT [DF_StgTmgfDemand_ModifiedOnDtm] DEFAULT (sysdatetime()) NOT NULL,
    [ModifiedByNm]     VARCHAR (25)     CONSTRAINT [DF_StgTmgfDemand_ModifiedByNm] DEFAULT (original_login()) NOT NULL
);

