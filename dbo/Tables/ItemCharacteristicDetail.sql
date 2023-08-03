CREATE TABLE [dbo].[ItemCharacteristicDetail] (
    [ProductDataManagementItemId]      VARCHAR (60)   NULL,
    [ProductDataManagementItemClassNm] NVARCHAR (128) NULL,
    [CharacteristicNm]                 VARCHAR (30)   NULL,
    [CharacteristicValue]              VARCHAR (200)  NULL,
    [CreatedOn]                        DATETIME       CONSTRAINT [DF_ItemCharacteristicDetail_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]                        VARCHAR (25)   CONSTRAINT [DF_ItemCharacteristicDetail_CreatedBy] DEFAULT (user_name()) NOT NULL
);

