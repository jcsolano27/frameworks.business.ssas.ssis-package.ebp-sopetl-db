CREATE TABLE [sop].[PlanningFigureBackup] (
    [PlanningMonthNbr] INT          NOT NULL,
    [PlanVersionId]    INT          NOT NULL,
    [CorridorId]       INT          NOT NULL,
    [ProductId]        INT          NOT NULL,
    [ProfitCenterCd]   INT          NOT NULL,
    [CustomerId]       INT          NOT NULL,
    [KeyFigureId]      INT          NOT NULL,
    [TimePeriodId]     INT          NOT NULL,
    [Quantity]         FLOAT (53)   NULL,
    [CreatedOnDtm]     DATETIME     NOT NULL,
    [CreatedByNm]      VARCHAR (25) NOT NULL,
    [ModifiedOnDtm]    DATETIME     NOT NULL,
    [ModifiedByNm]     VARCHAR (25) NOT NULL
);

