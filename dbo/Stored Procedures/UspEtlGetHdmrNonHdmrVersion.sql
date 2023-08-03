CREATE PROC [dbo].[UspEtlGetHdmrNonHdmrVersion]
@TypeVersion INT
--0 HDMR
--1 NONHDMR

AS
/*********************************************************************************
    Author:         Ana Paula Tairum
     
    Purpose:        Get lisf of Hdmr version 

    Called by:      SSIS - Hana.dtsx
         
    Result sets:    None
      
    Date        User						Description
***************************************************************************-
    2022-09-26  Ana Paula Tairum			Initial Release

*********************************************************************************/
--EXEC dbo.UspEtlGetHdmrNonHdmrVersion 

SET NOCOUNT, XACT_ABORT, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL ON;

SET NUMERIC_ROUNDABORT OFF;

IF @TypeVersion = 0 --> 'HDMR'
BEGIN
    -- Error and transaction handling setup ********************************************************

	DECLARE @HdmrVersions VARCHAR(1000) = 	(SELECT VersionsId FROM dbo.SvdLoadStatus WHERE SourceNm = 'HDMRPublishDetail')
		,	@Counter INT = 1

	DECLARE @CounterLimit INT = LEN(@HdmrVersions) - LEN(REPLACE(@HdmrVersions,',','')) + 1
		,	@FirstPipe INT = (SELECT CASE WHEN CHARINDEX(',', @HdmrVersions) = 0 THEN LEN(@HdmrVersions) ELSE CHARINDEX(',', @HdmrVersions) END)

	DECLARE @HdmrVersionList TABLE
	(
		SnapshotId INT
	)

	WHILE (@Counter <= @CounterLimit)
	BEGIN

		INSERT INTO @HdmrVersionList
		SELECT CAST(REPLACE(LEFT(@HdmrVersions,@FirstPipe),',','') AS INT)

		SET @HdmrVersions =  SUBSTRING(@HdmrVersions,@FirstPipe+1,LEN(@HdmrVersions))
		SET @Counter  = @Counter  + 1

	END

	SELECT SSV.SvdSourceVersionId
	FROM @HdmrVersionList  HDMR
		INNER JOIN dbo.SvdSourceVersion SSV 
			ON SSV.SourceVersionId = HDMR.SnapshotId
			AND SSV.SvdSourceApplicationId = (SELECT [dbo].[CONST_SvdSourceApplicationId_Hdmr]())
END
ELSE IF @TypeVersion = 1 --> 'NONHDMR'
BEGIN
	SELECT 
		SvdSourceVersionId
	FROM [dbo].[SvdSourceVersion]
	WHERE 
	SvDSourceApplicationId = (SELECT [dbo].[CONST_SvdSourceApplicationId_NonHdmr]())
	AND PlanningMonth IN (
		SELECT 
			DISTINCT 
			PlanningFiscalYearMonthNbr 
		FROM [dbo].StgNonHdmrProducts
	);
END

