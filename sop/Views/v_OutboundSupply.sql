CREATE VIEW [sop].[v_OutboundSupply] AS
(
SELECT
	PlanningMonthNbr	
,	PV.PlanVersionNm
,	PV.PlanVersionDsc
,	PV.SourceVersionId
,	SSI.SourceSystemNm
,	C.CorridorNm
,	C.CorridorDsc
,	P.SourceProductId	
,	PT.ProductTypeNm
,	ProfitCenterCd	
,	CUS.SourceCustomerId
,	KF.KeyFigureNm
,	KF.UnitOfMeasureCd
,	TP.FiscalYearQuarterNbr
,	Quantity	
,	PF.CreatedOnDtm	
,	PF.ModifiedOnDtm	

FROM [sop].[PlanningFigure] PF
	JOIN [sop].PlanVersion PV	ON PV.PlanVersionId		= PF.PlanVersionId
	JOIN [sop].Scenario S		ON S.ScenarioId			= PV.ScenarioId
	JOIN [sop].SourceSystem SSI	ON SSI.SourceSystemId	= PV.SourceSystemId
	JOIN [sop].Corridor C		ON C.CorridorId			= PF.CorridorId
	JOIN [sop].Product P		ON P.ProductId			= PF.ProductId
	JOIN [sop].ProductType PT	ON PT.ProductTypeId		= P.ProductTypeId
	JOIN [sop].Customer CUS		ON CUS.CustomerId		= PF.CustomerId
	JOIN [sop].KeyFigure KF		ON KF.KeyFigureId		= PF.KeyFigureId
	JOIN [sop].TimePeriod TP	ON TP.TimePeriodId		= PF.TimePeriodId
WHERE (PF.KeyFigureId = [sop].[CONST_KeyFigureId_ProdCoSupplyVolumeBe]()
OR PF.KeyFigureId = [sop].[CONST_KeyFigureId_ProdCoSupplyDollarsBe]()
OR PF.KeyFigureId = [sop].[CONST_KeyFigureId_TmgfSupplyResponseDollarsFe]()
or PF.KeyFigureId = [sop].[CONST_KeyFigureId_TmgfSupplyResponseVolumeFe]())
)