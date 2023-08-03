CREATE TABLE [dbo].[SvdSourceVersion] (
    [SvdSourceVersionId]     INT            IDENTITY (0, 1) NOT NULL,
    [PlanningMonth]          INT            NOT NULL,
    [SvdSourceApplicationId] INT            NOT NULL,
    [SourceVersionId]        INT            NOT NULL,
    [SourceVersionNm]        VARCHAR (1000) NULL,
    [SourceVersionType]      VARCHAR (100)  NULL,
    [CreatedOn]              DATETIME       DEFAULT (getdate()) NOT NULL,
    [CreatedBy]              VARCHAR (25)   DEFAULT (original_login()) NOT NULL,
    [RestrictHorizonInd]     BIT            DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([SvdSourceVersionId] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IX_NC_SvdSourceVersion]
    ON [dbo].[SvdSourceVersion]([SourceVersionId] ASC)
    INCLUDE([PlanningMonth], [SvdSourceApplicationId], [SourceVersionNm], [SourceVersionType]);

