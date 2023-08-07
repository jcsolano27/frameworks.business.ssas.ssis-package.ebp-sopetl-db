USE [SVD]
GO

/****** Object:  Table [sop].[SPOR]    Script Date: 8/6/2023 6:24:58 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [sop].[SPOR](
	[PlanningMonthNbr] [int] NULL,
	[PlanVersionId] [int] NULL,
	[ProductId] [int] NOT NULL,
	[ProfitCenterCd] [int] NOT NULL,
	[SourceProductId] [nvarchar](30) NOT NULL,
	[KeyFigureId] [int] NULL,
	[TimePeriodId] [int] NOT NULL,
	[Quantity] [decimal](38, 10) NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [varchar](25) NOT NULL,
	[ModifiedOn] [datetime] NOT NULL,
	[ModifiedBy] [varchar](25) NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [sop].[SPOR] ADD  DEFAULT (getdate()) FOR [CreatedOn]
GO

ALTER TABLE [sop].[SPOR] ADD  DEFAULT (original_login()) FOR [CreatedBy]
GO

ALTER TABLE [sop].[SPOR] ADD  DEFAULT (getdate()) FOR [ModifiedOn]
GO

ALTER TABLE [sop].[SPOR] ADD  DEFAULT (original_login()) FOR [ModifiedBy]
GO


