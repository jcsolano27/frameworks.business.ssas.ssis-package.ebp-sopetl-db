CREATE TABLE [dbo].[StgActualBilling] (
    [ApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]        VARCHAR (50) NOT NULL,
    [ItemClass]       VARCHAR (25) NOT NULL,
    [LinkToProduct]   BIGINT       NULL,
    [YearWw]          INT          NOT NULL,
    [MmbpCgid]        FLOAT (53)   NULL,
    [CreatedOn]       DATETIME     CONSTRAINT [DF_StgActualBilling_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25) CONSTRAINT [DF_StgActualBilling_CreatedBy] DEFAULT (user_name()) NOT NULL
);

