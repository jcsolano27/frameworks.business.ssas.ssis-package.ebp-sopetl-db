CREATE TABLE [dbo].[GuiUIDataColumn] (
    [DataSheetID]    INT          NOT NULL,
    [DataColumnID]   INT          NOT NULL,
    [DataColumnName] VARCHAR (50) NOT NULL,
    [isLocked]       BIT          NULL,
    [isXMLColumn]    BIT          NULL,
    [ValidationProc] VARCHAR (50) NULL,
    [UpdatedOn]      DATETIME     CONSTRAINT [DF_UIDataColumn_UpdatedOn] DEFAULT (getdate()) NOT NULL,
    [UpdatedBy]      VARCHAR (25) CONSTRAINT [DF_UIDataColumn_UpdatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_UIDataColumn] PRIMARY KEY CLUSTERED ([DataSheetID] ASC, [DataColumnID] ASC, [DataColumnName] ASC)
);

