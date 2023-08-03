CREATE TABLE [dbo].[temp_fran_demandForecast] (
    [SourceApplicationName]   VARCHAR (25) NOT NULL,
    [SnOPDemandForecastMonth] INT          NOT NULL,
    [SnOPDemandProductId]     INT          NOT NULL,
    [ProfitCenterCd]          INT          NOT NULL,
    [YearMm]                  INT          NOT NULL,
    [ParameterId]             INT          NOT NULL,
    [Quantity]                FLOAT (53)   NULL,
    [CreatedOn]               DATETIME     NOT NULL,
    [CreatedBy]               VARCHAR (25) NOT NULL,
    [ModifiedOn]              DATETIME     NULL
);

