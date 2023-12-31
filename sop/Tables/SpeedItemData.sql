﻿CREATE TABLE [sop].[SpeedItemData] (
    [OwningSystemId]                  NVARCHAR (3)     NULL,
    [ItemId]                          NVARCHAR (21)    NULL,
    [ItemDsc]                         NVARCHAR (255)   NULL,
    [ItemFullDsc]                     NVARCHAR (512)   NULL,
    [CommodityCd]                     NVARCHAR (10)    NULL,
    [ItemClassCd]                     NVARCHAR (4)     NULL,
    [ItemClassNm]                     NVARCHAR (127)   NULL,
    [ItemRecommendInd]                NVARCHAR (1)     NULL,
    [ItemRecommendId]                 INT              NULL,
    [UserItemTypeNm]                  NVARCHAR (127)   NULL,
    [EffectiveRevisionCd]             NVARCHAR (2)     NULL,
    [CurrentRevisionCd]               NVARCHAR (2)     NULL,
    [ItemRevisionCd]                  NVARCHAR (2)     NULL,
    [NetWeightQty]                    DECIMAL (38, 10) NULL,
    [MakeBuyNm]                       NVARCHAR (20)    NULL,
    [UnitOfMeasureCd]                 NVARCHAR (3)     NULL,
    [UnitOfWeightDim]                 NVARCHAR (3)     NULL,
    [DepartmentCd]                    NVARCHAR (10)    NULL,
    [DepartmentNm]                    NVARCHAR (50)    NULL,
    [MaterialTypeCd]                  NVARCHAR (4)     NULL,
    [MaterialTypeDsc]                 NVARCHAR (25)    NULL,
    [GrossWeightQty]                  DECIMAL (38, 10) NULL,
    [GlobalTradeIdentifierNbr]        NVARCHAR (18)    NULL,
    [BusinessUnitId]                  NVARCHAR (2)     NULL,
    [BusinessUnitNm]                  NVARCHAR (16)    NULL,
    [LastClassChangeDtm]              DATETIME2 (6)    NULL,
    [TemplateId]                      INT              NULL,
    [TemplateNm]                      NVARCHAR (255)   NULL,
    [OwningSystemLastModificationDtm] DATETIME2 (6)    NULL,
    [SourceSystemNm]                  NVARCHAR (11)    NULL,
    [CreateAgentId]                   NVARCHAR (20)    NULL,
    [ChangeAgentId]                   NVARCHAR (20)    NULL,
    [DeleteInd]                       INT              NULL,
    [CreatedOnDtm]                    DATETIME         CONSTRAINT [DF_SpeedItemData_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]                     VARCHAR (25)     CONSTRAINT [DF_SpeedItemData_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]                   DATETIME         CONSTRAINT [DF_SpeedItemData_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]                    VARCHAR (25)     CONSTRAINT [DF_SpeedItemData_ModifiedByNm] DEFAULT (original_login()) NOT NULL
);

