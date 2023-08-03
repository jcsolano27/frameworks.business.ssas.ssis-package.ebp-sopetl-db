CREATE TABLE [dbo].[StgDiePrepItemsMap] (
    [ItemId]              VARCHAR (50)  NOT NULL,
    [ItemDescription]     VARCHAR (50)  NULL,
    [SdaFamily]           VARCHAR (50)  NULL,
    [MMCodeName]          VARCHAR (50)  NULL,
    [DLCPProc]            VARCHAR (50)  NULL,
    [SnOPDemandProductId] INT           NULL,
    [SnOPDemandProductNm] VARCHAR (100) NULL,
    [RemoveInd]           BIT           CONSTRAINT [DF_StgDiePrepItemsMap_RemoveInd] DEFAULT ((0)) NULL,
    [CreatedOn]           DATETIME      CONSTRAINT [DF_StgDiePrepItemsMap_CreatedOn] DEFAULT (getdate()) NULL,
    [CreatedBy]           VARCHAR (25)  CONSTRAINT [DF_StgDiePrepItemsMap_CreatedBy] DEFAULT (user_name()) NULL
);

