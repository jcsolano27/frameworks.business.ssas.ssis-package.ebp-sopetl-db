CREATE TABLE [sop].[StgSupplyForecast] (
    [KeyFigureId]          INT              NULL,
    [PlanningMonth]        INT              NULL,
    [VersionId]            INT              NULL,
    [Process]              VARCHAR (256)    NULL,
    [WaferItemName]        VARCHAR (256)    NULL,
    [WaferItemDescription] VARCHAR (256)    NULL,
    [SortItemName]         VARCHAR (256)    NULL,
    [SortItemDescription]  VARCHAR (256)    NULL,
    [LocationName]         VARCHAR (256)    NULL,
    [IntelYearWw]          INT              NULL,
    [IntelYearQuarter]     INT              NULL,
    [SortOutQty]           DECIMAL (20, 10) NULL,
    [WaferOutQty]          DECIMAL (20, 10) NULL,
    [PackageSystemId]      INT              DEFAULT ([sop].[CONST_PackageSystemId_Supply]()) NULL,
    [SourceSystemId]       INT              DEFAULT ([sop].[CONST_SourceSystemId_OneMps]()) NULL,
    [CreatedOnDtm]         DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]          [sysname]        DEFAULT (original_login()) NOT NULL
);

