CREATE TABLE [sop].[StgRevenueForecast] (
    [EtlOrigin]                          [sysname]        NOT NULL,
    [FiscalCalendarId]                   INT              NULL,
    [ProductNodeId]                      NVARCHAR (20)    NULL,
    [ProfitCenterCd]                     NVARCHAR (20)    NULL,
    [ScenarioId]                         INT              NULL,
    [ScenarioNm]                         NVARCHAR (30)    NULL,
    [VersionId]                          NVARCHAR (20)    NULL,
    [VersionNm]                          NVARCHAR (100)   NULL,
    [BusinessUnitFinancePlanOfRecordAmt] DECIMAL (38, 10) NULL,
    [BusinessUnitFinancePlanOfRecordQty] DECIMAL (38, 10) NULL,
    [RevOptQty]                          DECIMAL (38, 10) NULL,
    [RevOptAmt]                          DECIMAL (38, 10) NULL,
    [PackageSystemId]                    INT              DEFAULT ([sop].[CONST_PackageSystemId_Revenue]()) NULL,
    [SourceSystemId]                     INT              DEFAULT ([sop].[CONST_SourceSystemId_SapIbp]()) NULL,
    [CreatedOnDtm]                       DATETIME         DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]                        [sysname]        DEFAULT (original_login()) NOT NULL
);

