CREATE TABLE [dbo].[StgActualBoh] (
    [ApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]        VARCHAR (50) NULL,
    [LocationName]    VARCHAR (50) NOT NULL,
    [SupplyCategory]  VARCHAR (50) NOT NULL,
    [YearWw]          INT          NOT NULL,
    [Boh]             FLOAT (53)   NULL,
    [SourceAsOf]      DATETIME     NULL,
    [CreatedOn]       DATETIME     CONSTRAINT [DF_StgDataActualBoh_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]       VARCHAR (25) CONSTRAINT [DF_StgDataActualBoh_Createdby] DEFAULT (original_login()) NOT NULL
);

