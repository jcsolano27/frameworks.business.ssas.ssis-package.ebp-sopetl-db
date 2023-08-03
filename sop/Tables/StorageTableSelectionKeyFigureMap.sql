CREATE TABLE [sop].[StorageTableSelectionKeyFigureMap] (
    [StorageTableSelectionId] INT NOT NULL,
    [KeyFigureId]             INT NOT NULL,
    CONSTRAINT [PkStorageTableSelectionKeyFigureMap] PRIMARY KEY CLUSTERED ([StorageTableSelectionId] ASC, [KeyFigureId] ASC),
    FOREIGN KEY ([KeyFigureId]) REFERENCES [sop].[KeyFigure] ([KeyFigureId]),
    FOREIGN KEY ([StorageTableSelectionId]) REFERENCES [sop].[StorageTableSelection] ([StorageTableSelectionId])
);

