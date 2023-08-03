CREATE TABLE [dbo].[GuiUIControl] (
    [ControlID]                INT           NOT NULL,
    [ControlTypeID]            INT           NOT NULL,
    [ControlName]              VARCHAR (50)  NOT NULL,
    [ControlLabel]             VARCHAR (250) NOT NULL,
    [ControlSizeID]            INT           NULL,
    [ControlOfficeImageString] VARCHAR (50)  NULL,
    [PopulateControlDBItem]    VARCHAR (50)  NULL,
    [ControlColumnName]        VARCHAR (50)  NULL,
    [IDColumnName]             VARCHAR (50)  NULL,
    [ExecControlDBItem]        VARCHAR (50)  NULL,
    [IsVisibleOnInit]          BIT           NULL,
    [UpdatedOn]                DATETIME      CONSTRAINT [DF_UIControl_UpdatedOn] DEFAULT (getdate()) NOT NULL,
    [UpdatedBy]                VARCHAR (25)  CONSTRAINT [DF_UIControl_UpdatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_UIControl] PRIMARY KEY CLUSTERED ([ControlID] ASC)
);

