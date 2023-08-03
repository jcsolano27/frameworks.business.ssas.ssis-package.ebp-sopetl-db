CREATE TABLE [dbo].[StgAirActualSupply] (
    [ApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]        VARCHAR (50) NOT NULL,
    [ItemClass]       VARCHAR (25) NOT NULL,
    [LocationName]    VARCHAR (50) NOT NULL,
    [YearWw]          INT          NOT NULL,
    [QuantityType]    VARCHAR (50) NOT NULL,
    [Quantity]        FLOAT (53)   NULL,
    [CreatedOn]       DATETIME     CONSTRAINT [DF_StgAirActualSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25) CONSTRAINT [DF_StgAirActualSupply_CreatedBy] DEFAULT (user_name()) NOT NULL
);

