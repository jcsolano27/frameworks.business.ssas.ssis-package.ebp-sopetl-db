CREATE TABLE [dbo].[ChangeDemandComments] (
    [PrimaryKey] INT           IDENTITY (1, 1) NOT NULL,
    [Date]       DATETIME      NULL,
    [User]       VARCHAR (100) NULL,
    [Comments]   VARCHAR (MAX) NULL,
    CONSTRAINT [PK_ChangeDemandComments] PRIMARY KEY CLUSTERED ([PrimaryKey] ASC)
);

