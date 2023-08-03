CREATE TABLE [dbo].[EtlSsisParameters] (
    [ConfigSsisParametersId] INT            IDENTITY (1, 1) NOT NULL,
    [Created]                DATETIME2 (7)  CONSTRAINT [DF_ConfigSsisParameters_Created] DEFAULT (sysdatetime()) NOT NULL,
    [createdBy]              VARCHAR (100)  CONSTRAINT [DF_ConfigSsisParameters_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]              DATETIME2 (7)  NULL,
    [UpdatedBy]              DATETIME2 (7)  NULL,
    [Parameter]              VARCHAR (100)  NOT NULL,
    [ParameterValue]         VARCHAR (8000) NOT NULL,
    CONSTRAINT [PK_ConfigSsisParameters] PRIMARY KEY CLUSTERED ([ConfigSsisParametersId] ASC)
);

