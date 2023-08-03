CREATE TABLE [dbo].[Parameters] (
    [ParameterId]          INT           NOT NULL,
    [ParameterName]        VARCHAR (50)  NOT NULL,
    [ParameterDescription] VARCHAR (255) NULL,
    [Active]               BIT           NOT NULL,
    [SourceParameterName]  VARCHAR (50)  NULL,
    [CreatedOn]            DATETIME      CONSTRAINT [DF_Parameters_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]            VARCHAR (25)  CONSTRAINT [DF_Parameters_CreatedBy] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_SvdParameters] PRIMARY KEY CLUSTERED ([ParameterId] ASC)
);

