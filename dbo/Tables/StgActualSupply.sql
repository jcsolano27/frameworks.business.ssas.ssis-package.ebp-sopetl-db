CREATE TABLE [dbo].[StgActualSupply] (
    [ApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]        VARCHAR (50) NOT NULL,
    [ScheduleTypeNm]  VARCHAR (25) NOT NULL,
    [StarOutCd]       VARCHAR (50) NOT NULL,
    [ScheduleDt]      VARCHAR (50) NOT NULL,
    [Quantity]        FLOAT (53)   NULL,
    [CreatedOn]       DATETIME     CONSTRAINT [DF_StgActualSupply_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25) CONSTRAINT [DF_StgActualSupply_CreatedBy] DEFAULT (user_name()) NOT NULL
);

