CREATE TABLE [dbo].[ActualFgMovements] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]              VARCHAR (25) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [MovementType]          VARCHAR (25) NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_ActualFgMovements_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_ActualFgMovements_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]            DATETIME     CONSTRAINT [DF_ActualFgMovements_ModifiedOn] DEFAULT (getdate()) NULL,
    CONSTRAINT [PK_ActualFgMovements] PRIMARY KEY CLUSTERED ([ItemName] ASC, [YearWw] ASC, [MovementType] ASC)
);

