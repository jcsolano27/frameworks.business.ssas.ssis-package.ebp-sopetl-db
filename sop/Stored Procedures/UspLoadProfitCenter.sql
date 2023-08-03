----/********************************************************************************
----
----    Purpose:        This proc is used to load [sop].[ProfitCenter] data
----                    Source:      [dbo].[ProfitCenterHierarchy]
----                    Destination: [sop].[ProfitCenter]
----    Called by:      SSIS
----
----    Result sets:    None
----
----    Date			User            Description
----*********************************************************************************
----	2023-06-27		caiosanx		Initial Release
----*********************************************************************************/

CREATE   PROC [sop].[UspLoadProfitCenter]
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

DECLARE @SourceSystemId INT = sop.CONST_SourceSystemId_SapMdg();

MERGE sop.ProfitCenter T
USING
(
    SELECT ProfitCenterCd,
           ProfitCenterNm,
           DivisionNm,
           GroupNm,
           SuperGroupNm,
           DivisionDsc,
           GroupDsc,
           SuperGroupDsc,
           IsActive ActiveInd,
           ProfitCenterHierarchyId SourceProfitCenterId
    FROM dbo.ProfitCenterHierarchy
) S
ON S.ProfitCenterCd = T.ProfitCenterCd
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        ProfitCenterCd,
        ProfitCenterNm,
        DivisionNm,
        GroupNm,
        SuperGroupNm,
        DivisionDsc,
        GroupDsc,
        SuperGroupDsc,
        ActiveInd,
        SourceProfitCenterId,
        SourceSystemId,
        CreatedOnDtm,
        CreatedByNm,
        ModifiedOnDtm,
        ModifiedByNm
    )
    VALUES
    (   S.ProfitCenterCd, S.ProfitCenterNm, S.DivisionNm, S.GroupNm, S.SuperGroupNm, S.DivisionDsc, S.GroupDsc,
        S.SuperGroupDsc, S.ActiveInd, S.SourceProfitCenterId, CASE
                                                                  WHEN S.SourceProfitCenterId = -1 THEN
                                                                      0
                                                                  ELSE
                                                                      @SourceSystemId
                                                              END, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
WHEN MATCHED AND (
                     T.ProfitCenterNm <> S.ProfitCenterNm
                     OR T.DivisionNm <> S.DivisionNm
                     OR T.GroupNm <> S.GroupNm
                     OR T.SuperGroupNm <> S.SuperGroupNm
                     OR T.DivisionDsc <> S.DivisionDsc
                     OR T.GroupDsc <> S.GroupDsc
                     OR T.SuperGroupDsc <> S.SuperGroupDsc
                     OR T.ActiveInd <> S.ActiveInd
                     OR T.SourceProfitCenterId <> S.SourceProfitCenterId
                     OR T.SourceSystemId <> CASE
                                                WHEN S.SourceProfitCenterId = -1 THEN
                                                    0
                                                ELSE
                                                    @SourceSystemId
                                            END
                 ) THEN
    UPDATE SET T.ProfitCenterNm = S.ProfitCenterNm,
               T.DivisionNm = S.DivisionNm,
               T.GroupNm = S.GroupNm,
               T.SuperGroupNm = S.SuperGroupNm,
               T.DivisionDsc = S.DivisionDsc,
               T.GroupDsc = S.GroupDsc,
               T.SuperGroupDsc = S.SuperGroupDsc,
               T.ActiveInd = S.ActiveInd,
               T.SourceProfitCenterId = S.SourceProfitCenterId,
               T.SourceSystemId = CASE
                                      WHEN S.SourceProfitCenterId = -1 THEN
                                          0
                                      ELSE
                                          @SourceSystemId
                                  END,
               T.ModifiedOnDtm = DEFAULT,
               T.ModifiedByNm = DEFAULT;
