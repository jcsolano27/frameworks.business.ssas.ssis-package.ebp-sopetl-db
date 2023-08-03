




CREATE FUNCTION [dbo].[CONST_SnOPProductTypeNm]()
RETURNS VARCHAR(10)
AS
BEGIN
	
	DECLARE @SnOPProductTypeNm Varchar(10); 
	
	set @SnOPProductTypeNm = 'Processor'

	RETURN @SnOPProductTypeNm
END
