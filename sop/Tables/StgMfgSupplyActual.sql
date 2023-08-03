CREATE TABLE [sop].[StgMfgSupplyActual] (
    [SourceProductId]          VARCHAR (30)  NOT NULL,
    [ProductType]              VARCHAR (100) NOT NULL,
    [FromLocationId]           NVARCHAR (25) NOT NULL,
    [YearWorkweekNbr]          INT           NULL,
    [dieoutact]                FLOAT (53)    NULL,
    [UnitOfMeasureCd]          VARCHAR (30)  NULL,
    [waferoutact]              FLOAT (53)    NULL,
    [SecondaryUnitOfMeasureCd] VARCHAR (30)  NULL,
    [CreatedOn]                DATETIME      DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                VARCHAR (25)  DEFAULT (original_login()) NOT NULL
);

