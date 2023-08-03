CREATE TABLE [sop].[MfgSupplyActual] (
    [CorridorId]      INT              DEFAULT ((0)) NULL,
    [ProductId]       INT              NOT NULL,
    [SourceProductId] VARCHAR (30)     NOT NULL,
    [ProfitCenterCd]  INT              NULL,
    [KeyFigureId]     INT              NOT NULL,
    [TimePeriodId]    INT              NOT NULL,
    [Quantity]        DECIMAL (38, 10) NULL,
    [CreatedOn]       DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25)     DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]      DATETIME         DEFAULT (getdate()) NOT NULL,
    [ModifiedBy]      VARCHAR (25)     DEFAULT (original_login()) NOT NULL
);

