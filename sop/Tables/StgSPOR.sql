USE [SVD]
GO

/****** Object:  Table [sop].[StgSPOR]    Script Date: 8/6/2023 6:25:15 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [sop].[StgSPOR](
	[PlanningMonthNbr] [int] NULL,
	[SourceProductId] [nvarchar](30) NOT NULL,
	[ProfitCenterNm] [nvarchar](100) NOT NULL,
	[KeyFigureNm] [nvarchar](100) NOT NULL,
	[ScenarioNm] [nvarchar](50) NOT NULL,
	[FiscalYearQuarterNbr] [int] NOT NULL,
	[Quantity] [float] NULL,
	[CreatedOn] [datetime] NOT NULL,
	[CreatedBy] [nvarchar](25) NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [sop].[StgSPOR] ADD  DEFAULT (getdate()) FOR [CreatedOn]
GO

ALTER TABLE [sop].[StgSPOR] ADD  DEFAULT (original_login()) FOR [CreatedBy]
GO


