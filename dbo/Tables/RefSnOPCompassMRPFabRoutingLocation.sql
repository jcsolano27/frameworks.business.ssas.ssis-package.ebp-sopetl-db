CREATE TABLE [dbo].[RefSnOPCompassMRPFabRoutingLocation] (
    [RowId]               INT            IDENTITY (1, 1) NOT NULL,
    [LocationName]        NVARCHAR (250) NOT NULL,
    [IsVisibleDownstream] BIT            DEFAULT ((1)) NOT NULL,
    [UpdatedOn]           DATETIME       NOT NULL,
    [UpdatedBy]           VARCHAR (25)   NOT NULL,
    CONSTRAINT [PK_RefSnOPCompassMRPFabRoutingLocation] PRIMARY KEY CLUSTERED ([RowId] ASC)
);

