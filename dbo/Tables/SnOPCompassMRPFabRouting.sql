﻿CREATE TABLE [dbo].[SnOPCompassMRPFabRouting] (
    [RowId]                 BIGINT          IDENTITY (1, 1) NOT NULL,
    [PublishLogId]          INT             NOT NULL,
    [SourceItem]            NVARCHAR (100)  NOT NULL,
    [ItemName]              NVARCHAR (100)  NOT NULL,
    [LocationName]          NVARCHAR (50)   NOT NULL,
    [ParameterTypeName]     NVARCHAR (255)  NOT NULL,
    [Quantity]              FLOAT (53)      NULL,
    [OriginalQuantity]      FLOAT (53)      NULL,
    [BucketType]            NVARCHAR (5)    NULL,
    [FiscalYearWorkWeekNbr] NVARCHAR (10)   NOT NULL,
    [FabProcess]            NVARCHAR (250)  NOT NULL,
    [DotProcess]            NVARCHAR (250)  NULL,
    [LrpDieNm]              NVARCHAR (250)  NULL,
    [TechNode]              NVARCHAR (250)  NULL,
    [SourceApplicationName] NVARCHAR (4)    NULL,
    [IsOverride]            BIT             DEFAULT ((0)) NOT NULL,
    [CreatedOn]             DATETIME        DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25)    DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]             DATETIME        DEFAULT (getdate()) NOT NULL,
    [UpdatedBy]             VARCHAR (25)    DEFAULT (original_login()) NOT NULL,
    [UpdateComment]         NVARCHAR (4000) DEFAULT ('Initial Load') NOT NULL,
    CONSTRAINT [PK_SnOPCompassMRPFabRouting] PRIMARY KEY CLUSTERED ([RowId] ASC),
    CONSTRAINT [UQ_SnOPCompassMRPFabRouting] UNIQUE NONCLUSTERED ([PublishLogId] ASC, [SourceItem] ASC, [ItemName] ASC, [LocationName] ASC, [ParameterTypeName] ASC, [FiscalYearWorkWeekNbr] ASC, [FabProcess] ASC)
);

