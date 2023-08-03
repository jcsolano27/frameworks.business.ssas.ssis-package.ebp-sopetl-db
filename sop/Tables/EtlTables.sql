CREATE TABLE [sop].[EtlTables] (
    [TableId]         INT            NOT NULL,
    [TableName]       VARCHAR (100)  NOT NULL,
    [StorageTables]   VARCHAR (100)  NOT NULL,
    [StagingTables]   VARCHAR (8000) NULL,
    [PurgeScript]     NVARCHAR (MAX) NOT NULL,
    [SourceSystemId]  INT            NOT NULL,
    [PackageSystemId] INT            NOT NULL,
    [LoadParameters]  VARCHAR (100)  NOT NULL,
    [Description]     VARCHAR (1000) NULL,
    [Keywords]        VARCHAR (200)  NULL,
    [Active]          BIT            CONSTRAINT [EtlTables_Active] DEFAULT ((1)) NOT NULL,
    [CreatedOn]       DATETIME       CONSTRAINT [EtlTables_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]       VARCHAR (25)   CONSTRAINT [EtlTables_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]       DATETIME       CONSTRAINT [EtlTables_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [UpdatedBy]       VARCHAR (25)   CONSTRAINT [EtlTables_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([TableId] ASC)
);

