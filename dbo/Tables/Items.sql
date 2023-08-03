CREATE TABLE [dbo].[Items] (
    [ItemName]                       VARCHAR (18)   NOT NULL,
    [IsActive]                       BIT            CONSTRAINT [DF_Items_IsActive] DEFAULT ((1)) NOT NULL,
    [ProductNodeId]                  INT            NOT NULL,
    [SnOPDemandProductId]            INT            NULL,
    [SnOPSupplyProductId]            INT            NULL,
    [CreatedOn]                      DATETIME       CONSTRAINT [DF_Items_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                      VARCHAR (25)   CONSTRAINT [DF_Items_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]                     DATETIME       CONSTRAINT [DF_Items_ModifiedOn] DEFAULT (getdate()) NULL,
    [ModifiedBy]                     VARCHAR (25)   CONSTRAINT [DF_Items_ModifiedBy] DEFAULT (user_name()) NULL,
    [ProductGenerationSeriesCd]      VARCHAR (255)  NULL,
    [SnOPWayness]                    NVARCHAR (30)  NULL,
    [DataCenterDemandInd]            NVARCHAR (5)   NULL,
    [SnOPBoardFormFactorCd]          NVARCHAR (30)  NULL,
    [PlanningSupplyPackageVariantId] NVARCHAR (30)  NULL,
    [SdaFamily]                      VARCHAR (50)   NULL,
    [ItemDescription]                VARCHAR (100)  NULL,
    [NpiFlag]                        NVARCHAR (6)   NULL,
    [ItemClass]                      VARCHAR (25)   NULL,
    [FinishedGoodCurrentBusinessNm]  NVARCHAR (100) NULL,
    CONSTRAINT [PK_Items] PRIMARY KEY CLUSTERED ([ItemName] ASC)
);

