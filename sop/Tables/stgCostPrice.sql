CREATE TABLE [sop].[stgCostPrice] (
    [KeyFigureId]     INT            NOT NULL,
    [YearNbr]         INT            NOT NULL,
    [QtrNbr]          INT            NOT NULL,
    [PlanningMonth]   INT            DEFAULT ([dbo].[CONST_PlanningMonth]()) NULL,
    [CostGroup]       NVARCHAR (500) NOT NULL,
    [KeyFigureValue]  FLOAT (53)     NULL,
    [ItemId]          NVARCHAR (100) NULL,
    [SupplyProductId] INT            NULL,
    [CreatedOn]       DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25)   DEFAULT (original_login()) NOT NULL
);

