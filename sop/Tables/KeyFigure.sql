CREATE TABLE [sop].[KeyFigure] (
    [KeyFigureId]              INT           IDENTITY (1, 1) NOT NULL,
    [KeyFigureCd]              VARCHAR (10)  NOT NULL,
    [KeyFigureNm]              VARCHAR (100) NOT NULL,
    [KeyFigureCategoryNm]      VARCHAR (100) NOT NULL,
    [KeyFigureDsc]             VARCHAR (500) NULL,
    [KeyFigureAbbreviatedNm]   VARCHAR (25)  NOT NULL,
    [SourceKeyFigureNm]        VARCHAR (100) NOT NULL,
    [UnitOfMeasureCd]          NCHAR (10)    NOT NULL,
    [CalculatedInReportingInd] BIT           CONSTRAINT [DF_KeyFigure_CalculatedInReportingInd] DEFAULT ((0)) NOT NULL,
    [CalculationDsc]           VARCHAR (500) NULL,
    [DataStatusInd]            SMALLINT      CONSTRAINT [DF_KeyFigure_DataStatusInd] DEFAULT ((0)) NOT NULL,
    [ActiveInd]                BIT           CONSTRAINT [DF_KeyFigure_ActiveInd] DEFAULT ((1)) NOT NULL,
    [SourceSystemId]           INT           CONSTRAINT [DF_KeyFigure_SourceSystemId] DEFAULT ((0)) NOT NULL,
    [EtlReadyInd]              BIT           DEFAULT ((0)) NULL,
    [SecurityGroupId]          INT           NULL,
    [CreatedOnDtm]             DATETIME      DEFAULT (getdate()) NULL,
    [CreatedByNm]              [sysname]     DEFAULT (original_login()) NOT NULL,
    [ModifiedOnDtm]            DATETIME      DEFAULT (getdate()) NULL,
    [ModifiedByNm]             [sysname]     DEFAULT (original_login()) NOT NULL,
    CONSTRAINT [PK_KeyFigure] PRIMARY KEY CLUSTERED ([KeyFigureId] ASC),
    FOREIGN KEY ([SecurityGroupId]) REFERENCES [sop].[SecurityGroup] ([SecurityGroupId]),
    CONSTRAINT [FK_KeyFigure_SourceSystem] FOREIGN KEY ([SourceSystemId]) REFERENCES [sop].[SourceSystem] ([SourceSystemId])
);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_KeyFigure_KeyFigureCd]
    ON [sop].[KeyFigure]([KeyFigureCd] ASC);


GO
CREATE UNIQUE NONCLUSTERED INDEX [UC_KeyFigure_KeyFigureNm]
    ON [sop].[KeyFigure]([KeyFigureNm] ASC);

