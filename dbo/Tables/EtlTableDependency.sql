CREATE TABLE [dbo].[EtlTableDependency] (
    [ParentTableId] INT           NOT NULL,
    [ChildTableId]  INT           NOT NULL,
    [IsActive]      BIT           NOT NULL,
    [CreatedOn]     DATETIME2 (7) CONSTRAINT [DF_RefTableDependency_CreatedOn] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedBy]     VARCHAR (25)  CONSTRAINT [DF_RefTableDependency_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]     DATETIME2 (7) NULL,
    [UpdatedBy]     VARCHAR (25)  NULL,
    CONSTRAINT [PK_RefTableDependency] PRIMARY KEY CLUSTERED ([ParentTableId] ASC, [ChildTableId] ASC),
    CONSTRAINT [FK_RefTableDependencyChildTableId] FOREIGN KEY ([ChildTableId]) REFERENCES [dbo].[EtlTables] ([TableId]),
    CONSTRAINT [FK_RefTableDependencyParentTableId] FOREIGN KEY ([ParentTableId]) REFERENCES [dbo].[EtlTables] ([TableId])
);

