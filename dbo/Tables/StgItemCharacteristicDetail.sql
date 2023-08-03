CREATE TABLE [dbo].[StgItemCharacteristicDetail] (
    [ProductDataManagementItemId]      NVARCHAR (60)  NULL,
    [ProductDataManagementItemClassNm] NVARCHAR (128) NULL,
    [CharacteristicNm]                 NVARCHAR (30)  NULL,
    [CharacteristicValue]              NVARCHAR (100) NULL,
    [CreatedOn]                        DATETIME       CONSTRAINT [DF_StgItemCharacteristicDetail_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                        VARCHAR (25)   CONSTRAINT [DF_StgItemCharacteristicDetail_CreatedBy] DEFAULT (user_name()) NOT NULL
);

