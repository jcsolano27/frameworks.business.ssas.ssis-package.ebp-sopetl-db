CREATE TABLE [dbo].[GuiUIDataSheet] (
    [DataSheetID]   INT           NOT NULL,
    [DataSheetName] VARCHAR (30)  NOT NULL,
    [DataSheetType] VARCHAR (20)  NOT NULL,
    [FetchProcName] VARCHAR (100) NULL,
    [LoadProcName]  VARCHAR (100) NULL,
    [ColorID]       INT           CONSTRAINT [DF_UIDataSheet_ColorID] DEFAULT ((1)) NULL,
    [UpdatedOn]     DATETIME      CONSTRAINT [DF_UIDataSheet_UpdatedOn] DEFAULT (getdate()) NOT NULL,
    [UpdatedBy]     VARCHAR (25)  CONSTRAINT [DF_UIDataSheet_UpdatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_UIDataSheet] PRIMARY KEY CLUSTERED ([DataSheetID] ASC)
);

