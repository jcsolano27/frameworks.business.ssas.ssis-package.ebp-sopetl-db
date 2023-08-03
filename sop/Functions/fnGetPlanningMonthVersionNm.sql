CREATE FUNCTION [sop].[fnGetPlanningMonthVersionNm]  
(  
    @VersionNm CHAR(4)  
)  
RETURNS INT  
AS  
BEGIN  
  
    DECLARE @PlanningMonth INT = 0,  
            @CurrentYear INT = YEAR(GETDATE()),  
            @CurrentMonth INT = MONTH(GETDATE());  
  
    SET @PlanningMonth = CASE  
                             WHEN @VersionNm = 'MPOR' THEN  
                                 CONCAT(@CurrentYear, '03')  
                             WHEN @VersionNm = 'JPOR' THEN  
                                 CONCAT(@CurrentYear, '06')  
                             WHEN @VersionNm = 'SPOR' THEN  
                                 CONCAT(@CurrentYear, '09')  
                             WHEN @VersionNm = 'DPOR'  
                                  AND @CurrentMonth NOT IN ( 1, 2, 3 ) THEN  
                                 CONCAT(@CurrentYear, '12')  
                             WHEN @VersionNm = 'DPOR'  
                                  AND @CurrentMonth IN ( 1, 2, 3 ) THEN  
                                 CONCAT(@CurrentYear - 1, '12')  
                         END;  
  
    RETURN @PlanningMonth;  
END;