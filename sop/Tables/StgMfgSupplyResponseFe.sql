CREATE TABLE [sop].[StgMfgSupplyResponseFe] (
    [PlanningMonth]        INT           NULL,
    [SourceSystemId]       INT           NULL,
    [SourceVersionId]      INT           NULL,
    [Process]              VARCHAR (50)  NULL,
    [WaferItemName]        VARCHAR (100) NULL,
    [WaferItemDescription] VARCHAR (250) NULL,
    [SortItemName]         VARCHAR (100) NULL,
    [SortItemDescription]  VARCHAR (250) NULL,
    [LocationName]         VARCHAR (50)  NULL,
    [IntelYearWw]          INT           NULL,
    [IntelYearQuarter]     INT           NULL,
    [SortOutQty]           FLOAT (53)    NULL,
    [WaferOutQty]          FLOAT (53)    NULL,
    [CreatedOnDtm]         DATETIME      DEFAULT (getutcdate()) NOT NULL,
    [CreatedByNm]          NVARCHAR (25) DEFAULT (original_login()) NOT NULL
);

