CREATE TABLE [sop].[Corridor] (
    [CorridorId]     INT           IDENTITY (1, 1) NOT NULL,
    [CorridorNm]     VARCHAR (50)  NOT NULL,
    [CorridorDsc]    VARCHAR (100) NULL,
    [ActiveInd]      BIT           CONSTRAINT [DF_Corridor_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId] INT           NOT NULL,
    [CreatedOnDtm]   DATETIME      CONSTRAINT [DF_Corridor_CreatedOnDtm] DEFAULT (getdate()) NOT NULL,
    [CreatedByNm]    VARCHAR (25)  CONSTRAINT [DF_Corridor_CreatedByNm] DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]  DATETIME      CONSTRAINT [DF_Corridor_ModifiedOnDtm] DEFAULT (getdate()) NOT NULL,
    [ModifiedByNm]   VARCHAR (25)  CONSTRAINT [DF_Corridor_ModifiedByNm] DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_Corridor] PRIMARY KEY CLUSTERED ([CorridorId] ASC),
    CONSTRAINT [FK_Corridor_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_Corridor_CorridorNm]
    ON [sop].[Corridor]([CorridorNm] ASC);

