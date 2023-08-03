CREATE TABLE [dbo].[AirActualFgMovements] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]              VARCHAR (25) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [MovementType]          VARCHAR (25) NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_CreatedOnFG] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_CreatedByFG] DEFAULT (suser_sname()) NOT NULL,
    [ModifiedOn]            DATETIME     NULL
);

