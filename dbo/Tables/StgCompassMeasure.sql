CREATE TABLE [dbo].[StgCompassMeasure] (
    [EsdVersionId]        INT            NOT NULL,
    [PublishLogId]        INT            NULL,
    [VersionId]           INT            NULL,
    [ItemGroupNm]         NVARCHAR (100) NULL,
    [MeasureTypeNm]       NVARCHAR (100) NULL,
    [MeasureNm]           NVARCHAR (100) NULL,
    [ItemClass]           NVARCHAR (25)  NOT NULL,
    [ItemId]              NVARCHAR (100) NOT NULL,
    [ItemDsc]             NVARCHAR (500) NOT NULL,
    [LocationName]        NVARCHAR (50)  NULL,
    [YearWw]              INT            NOT NULL,
    [MeasureQty]          FLOAT (53)     NULL,
    [CreatedOn]           DATETIME       CONSTRAINT [DF_StgCompassMeasure_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]           NVARCHAR (25)  CONSTRAINT [DF_StgCompassMeasure_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [SnOPDemandProductId] INT            NULL
);

