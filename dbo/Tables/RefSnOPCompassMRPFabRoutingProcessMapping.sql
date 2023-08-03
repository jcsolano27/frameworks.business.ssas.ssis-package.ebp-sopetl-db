CREATE TABLE [dbo].[RefSnOPCompassMRPFabRoutingProcessMapping] (
    [RowId]               INT            IDENTITY (1, 1) NOT NULL,
    [Process]             NVARCHAR (25)  NOT NULL,
    [OriginalTechNode]    NVARCHAR (250) NOT NULL,
    [OverrideTechNode]    NVARCHAR (250) NULL,
    [IsVisibleDownstream] BIT            DEFAULT ((1)) NOT NULL,
    [UpdatedOn]           DATETIME       NOT NULL,
    [UpdatedBy]           VARCHAR (25)   NOT NULL,
    CONSTRAINT [PK_RefSnOPCompassMRPFabRoutingProcessMapping] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

