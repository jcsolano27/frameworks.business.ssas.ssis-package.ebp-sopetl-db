CREATE TABLE [dbo].[StgActualFgMovements] (
    [SourceApplicationName]  VARCHAR (25)  NOT NULL,
    [ItemName]               VARCHAR (25)  NOT NULL,
    [YearWw]                 INT           NOT NULL,
    [MovementType]           VARCHAR (25)  NOT NULL,
    [Quantity]               FLOAT (53)    NULL,
    [OriginalDebitCreditInd] NVARCHAR (10) NULL,
    [CreatedOn]              DATETIME      CONSTRAINT [DF_StgActualFgMovements_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25)  CONSTRAINT [DF_StgActualFgMovements_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [LastUpdatedDtm]         DATETIME      NULL
);

