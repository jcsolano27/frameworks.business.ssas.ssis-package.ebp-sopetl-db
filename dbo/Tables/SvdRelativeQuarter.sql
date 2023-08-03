CREATE TABLE [dbo].[SvdRelativeQuarter] (
    [QuarterNbr]            SMALLINT     NOT NULL,
    [CreatedBy]             VARCHAR (25) CONSTRAINT [DF_SvDRelativeQuarter_CreatedBy] DEFAULT (user_name()) NOT NULL,
    [CreatedOn]             DATETIME     CONSTRAINT [DF_SvDRelativeQuarter_CreatedOn] DEFAULT (getutcdate()) NOT NULL,
    [PlanningHorizonTypeCd] AS           (case when [QuarterNbr]<(0) then 'ACT' when [QuarterNbr]>=(0) AND [QuarterNbr]<(4) then 'SOE' when [QuarterNbr]>=(4) then 'SOP'  end),
    CONSTRAINT [PK_SvDRelativeQuarter] PRIMARY KEY CLUSTERED ([QuarterNbr] ASC)
);

