CREATE TABLE [sop].[StgProdcoRequestFeFull] (
    [PlanningMonth]  INT              NULL,
    [ProfitCenterCd] INT              NULL,
    [FabItemId]      INT              NULL,
    [SortItemId]     INT              NULL,
    [DSI]            VARCHAR (15)     NULL,
    [SortOutWw]      INT              NULL,
    [SortOutWwId]    INT              NULL,
    [WaferOuts]      INT              NULL,
    [AvgBeTPT]       INT              NULL,
    [FgOutWwId]      INT              NULL,
    [FgOutYearMM]    NVARCHAR (12)    NULL,
    [FrozenMonth]    INT              NOT NULL,
    [scaling_factor] FLOAT (53)       NULL,
    [Quantity]       DECIMAL (38, 10) NULL,
    [SourceSystemId] INT              NULL,
    [CreatedOnDtm]   DATETIME         CONSTRAINT [DF_StgProdcoRequestFeFull_CreatedOnDtm] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedByNm]    NVARCHAR (25)    CONSTRAINT [DF_StgProdcoRequestFeFull_CreatedbyNm] DEFAULT (original_login()) NOT NULL
);

