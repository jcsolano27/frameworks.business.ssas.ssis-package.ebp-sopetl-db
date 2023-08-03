CREATE TABLE [dbo].[SourceDataSSIS] (
    [SourceDataSSISId] INT           IDENTITY (1, 1) NOT FOR REPLICATION NOT NULL,
    [MetricNm]         VARCHAR (100) NOT NULL,
    [SourceNm]         VARCHAR (100) NOT NULL,
    [Quantity]         INT           CONSTRAINT [SourceDataSSISQuantity] DEFAULT ((0)) NULL,
    CONSTRAINT [PK_SourceDataSSISId] PRIMARY KEY CLUSTERED ([SourceDataSSISId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_SourceDataSSISMetricNm]
    ON [dbo].[SourceDataSSIS]([MetricNm] ASC);

