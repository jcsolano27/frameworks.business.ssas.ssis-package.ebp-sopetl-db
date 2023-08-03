CREATE TABLE [dbo].[PlatformAttachRate] (
    [BusinessEntityNm]     VARCHAR (50)   NOT NULL,
    [PrimaryComponentNm]   VARCHAR (100)  NOT NULL,
    [SecondaryComponentNm] VARCHAR (100)  NOT NULL,
    [EffectiveFromDt]      DATE           NOT NULL,
    [AttachRatePct]        DECIMAL (6, 4) NOT NULL,
    [CreatedBy]            VARCHAR (25)   DEFAULT (suser_sname()) NOT NULL,
    [CreatedOn]            DATETIME       DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_PlatformAttachRate] PRIMARY KEY CLUSTERED ([BusinessEntityNm] ASC, [PrimaryComponentNm] ASC, [SecondaryComponentNm] ASC, [EffectiveFromDt] ASC)
);

