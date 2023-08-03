CREATE TABLE [dbo].[Items_Manual_ProdBkp] (
    [ItemName]            VARCHAR (18) NOT NULL,
    [SnOPDemandProductId] INT          NULL,
    [SnOPSupplyProductId] INT          NULL,
    [CreatedOn]           DATETIME     NOT NULL,
    [CreatedBy]           VARCHAR (25) NOT NULL
);

