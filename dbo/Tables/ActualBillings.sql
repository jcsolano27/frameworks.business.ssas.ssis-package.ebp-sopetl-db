CREATE TABLE [dbo].[ActualBillings] (
    [SourceApplicationName] VARCHAR (25) NOT NULL,
    [ItemName]              VARCHAR (50) NOT NULL,
    [YearWw]                INT          NOT NULL,
    [ProfitCenterCd]        INT          NOT NULL,
    [Quantity]              FLOAT (53)   NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_ActualBillingsNetWithTmgUnits_CreatedOn] DEFAULT (getdate()) NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_ActualBillingsNetWithTmgUnits_CreatedBy] DEFAULT (original_login()) NOT NULL,
    [ModifiedOn]            DATETIME     CONSTRAINT [DF_ActualBillings_ModifiedOn] DEFAULT (getdate()) NULL,
    [ModifiedBy]            VARCHAR (25) CONSTRAINT [DF_ActualBillings_ModifiedBy] DEFAULT (user_name()) NULL,
    CONSTRAINT [PK_DataActualBillingsNetWithTMGUnits] PRIMARY KEY CLUSTERED ([ItemName] ASC, [YearWw] ASC, [ProfitCenterCd] ASC)
);


GO
CREATE NONCLUSTERED INDEX [IdxActualBillingsYearWw]
    ON [dbo].[ActualBillings]([YearWw] ASC)
    INCLUDE([Quantity]);

