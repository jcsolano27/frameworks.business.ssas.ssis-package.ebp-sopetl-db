----/********************************************************************************    
----    
----    Purpose:        This proc is used to load [sop].[Corridor] data    
----                    Source:      [sop].[StgCorridor]    
----                    Destination: [sop].[Corridor]    
----    Called by:      SSIS    
----    
----    Result sets:    None    
----    
----    Date		User            Description    
----*********************************************************************************    
----	2023-06-27  caiosanx		Initial Release
----*********************************************************************************/    

CREATE PROC [sop].[UspLoadCorridor]
WITH EXEC AS OWNER
AS
SET NOCOUNT ON;

MERGE sop.Corridor T
USING
(
    SELECT DISTINCT
           FabProcess CorridorNm,
           SourceSystemId
    FROM sop.StgCorridor
) S
ON S.CorridorNm = T.CorridorNm
   AND S.CorridorNm = T.CorridorDsc
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        CorridorNm,
        CorridorDsc,
        ActiveInd,
        SourceSystemId,
        CreatedOnDtm,
        CreatedByNm,
        ModifiedOnDtm,
        ModifiedByNm
    )
    VALUES
    (S.CorridorNm, S.CorridorNm, 1, S.SourceSystemId, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
WHEN MATCHED AND T.ActiveInd = 0 THEN
    UPDATE SET T.ActiveInd = 1,
               T.ModifiedOnDtm = GETDATE(),
               T.ModifiedByNm = ORIGINAL_LOGIN()
WHEN NOT MATCHED BY SOURCE AND CorridorId <> 0 THEN
    UPDATE SET T.ActiveInd = 0,
               T.ModifiedOnDtm = GETDATE(),
               T.ModifiedByNm = ORIGINAL_LOGIN();


