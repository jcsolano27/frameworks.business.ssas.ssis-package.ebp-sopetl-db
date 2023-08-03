CREATE TABLE [dbo].[ActualBoh] (
    [SourceApplicationName] VARCHAR (25) NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [LocationName]          VARCHAR (50) NOT NULL,
    [SupplyCategory]        VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [Boh]                   FLOAT (53)   NOT NULL,
    [SourceAsOf]            DATETIME     NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_ActualBoh_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_ActualBoh_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]             DATETIME     NULL,
    [UpdatedBy]             VARCHAR (25) NULL
);

