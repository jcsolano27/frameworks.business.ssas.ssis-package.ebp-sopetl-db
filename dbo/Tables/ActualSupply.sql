CREATE TABLE [dbo].[ActualSupply] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [ScheduleTypeNm]        VARCHAR (50) NOT NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_ActualSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_ActualSupply_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_ActualSupply] PRIMARY KEY CLUSTERED ([ScheduleTypeNm] ASC, [ItemName] ASC, [YearWw] ASC)
);

