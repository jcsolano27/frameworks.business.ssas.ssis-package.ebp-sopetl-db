CREATE TABLE [dbo].[AirActualSupply] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [ScheduleTypeNm]        VARCHAR (50) NOT NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_CreatedBy] DEFAULT (suser_sname()) NOT NULL
);

