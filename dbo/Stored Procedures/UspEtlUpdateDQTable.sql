CREATE PROC DBO.UspEtlUpdateDQTable 
    @Quantity INT = 0,
	@MetricNm VARCHAR(100) = NULL,
	@SourceNm VARCHAR(100) = NULL

AS
	UPDATE A
	SET Quantity = @Quantity
	from [dbo].[SourceDataSSIS] A
	where A.MetricNm = @MetricNm
	AND A.SourceNm = @SourceNm
;