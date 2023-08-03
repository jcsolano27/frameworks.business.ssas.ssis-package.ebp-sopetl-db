
CREATE PROC [dbo].[UspLoadProfitCenterHierarchy]

AS
----/*********************************************************************************
     
----    Purpose:        This proc is used to load data from Hana Product Hierarchy to SVD database   
----                    Source:      [dbo].[StgProfitCenterHierarchy]
----                    Destination: [dbo].[ProfitCenterHierarchy]

----    Called by:      SSIS
         
----    Result sets:    None
     
----	Parameters        
    
----    Date        User            Description
----***************************************************************************-
----    2022-08-29			        Initial Release
----	2023-02-08  vitorsix		Added new calculated column - GroupProfitCenterDescription
----	2023-04-13  psillosx		Included "Target.IsActive = 1" in "WHEN MATCHED" clause

----*********************************************************************************/
BEGIN
    SET NOCOUNT ON
    DECLARE @BatchId VARCHAR(100) = 'UspLoadProfitCenterHierarchy.' + CONVERT(VARCHAR(30), GETDATE(), 121) + '.' + SYSTEM_USER
    DECLARE @EmailMessage VARCHAR(1000) ='UspLoadProfitCenterHierarchy Successful'
    DECLARE @Prog VARCHAR(255)

    BEGIN TRY
        --Logging Start
		EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'UspLoadProfitCenterHierarchy', 'UspLoadUspLoadProfitCenterHierarchy','Load Items Data', 'BEGIN', NULL, @BatchId

		;WITH MAX_VALID AS (		
            SELECT 
                MAX(ValidToDt) ValidToDt, 
                ProfitCenterCd, 
                ProfitCenterNm,
                ProfitCenterDsc,
                DivisionCd, 
                DivisionNm, 
                GroupCd, 
                GroupNm, 
                SuperGroupCd, 
                SuperGroupNm
			from [dbo].[StgProfitCenterHierarchy]
            GROUP BY 
			ProfitCenterCd, ProfitCenterNm, ProfitCenterDsc, DivisionCd, DivisionNm, GroupCd, GroupNm, SuperGroupCd, SuperGroupNm
        )

        MERGE dbo.ProfitCenterHierarchy AS Target
        USING (

			select distinct 
                MAX(P.ProfitCenterHierarchyId) ProfitCenterHierarchyId, 
                P.ProfitCenterCd, 
                P.ProfitCenterNm,
                CASE
                    WHEN UPPER(P.ProfitCenterDsc) LIKE '%CORE%'
                        THEN 'Core'
                    WHEN UPPER(P.ProfitCenterDsc) LIKE '%WORKSTATION%'
                        THEN 'WorkStation'
                    ELSE 'Others'
                END AS GroupProfitCenterDescription,
                P.DivisionCd, 
                P.DivisionNm, 
                P.GroupCd, 
                P.GroupNm, 
                P.SuperGroupCd,
                P.SuperGroupNm
            from [dbo].[StgProfitCenterHierarchy] P 
            JOIN MAX_VALID M
            ON P.ProfitCenterCd = M.ProfitCenterCd AND
            P.ProfitCenterNm = M.ProfitCenterNm AND
            P.ProfitCenterDsc = M.ProfitCenterDsc AND
            P.DivisionCd = M.DivisionCd AND
            P.DivisionNm = M.DivisionNm AND
            P.GroupCd = M.GroupCd AND
            P.GroupNm = M.GroupNm AND
            P.SuperGroupCd = M.SuperGroupCd AND
            P.SuperGroupNm = M.SuperGroupNm AND
            P.ValidToDt = M.ValidToDt
			where P.ProfitCenterNm is not null
			GROUP BY P.ProfitCenterCd, P.ProfitCenterNm,CASE
                    WHEN UPPER(P.ProfitCenterDsc) LIKE '%CORE%'
                        THEN 'Core'
                    WHEN UPPER(P.ProfitCenterDsc) LIKE '%WORKSTATION%'
                        THEN 'WorkStation'
                    ELSE 'Others'
                END, P.DivisionCd, P.DivisionNm, P.GroupCd, P.GroupNm, P.SuperGroupCd, P.SuperGroupNm
        ) AS Source
        ON 
        Source.ProfitCenterCd = Target.ProfitCenterCd
        WHEN NOT MATCHED BY Target THEN
		INSERT (ProfitCenterHierarchyId, ProfitCenterCd,ProfitCenterNm,GroupProfitCenterDescription,DivisionDsc, DivisionNm,GroupDsc, GroupNm,SuperGroupDsc,SuperGroupNm)
        VALUES (
            Source.ProfitCenterHierarchyId,
            Source.ProfitCenterCd,
            Source.ProfitCenterNm,
            Source.GroupProfitCenterDescription,
            Source.DivisionCd,
            Source.DivisionNm,
            Source.GroupCd,
            Source.GroupNm,
            Source.SuperGroupCd,
            Source.SuperGroupNm
        )
        WHEN MATCHED THEN UPDATE SET
            Target.ProfitCenterHierarchyId = Source.ProfitCenterHierarchyId,
            Target.ProfitCenterCd = Source.ProfitCenterCd,
            Target.ProfitCenterNm = Source.ProfitCenterNm,
            Target.GroupProfitCenterDescription = Source.GroupProfitCenterDescription,
            Target.DivisionDsc = Source.DivisionCd,
            Target.DivisionNm = Source.DivisionNm,
            Target.GroupDsc = Source.GroupCd,
            Target.GroupNm = Source.GroupNm,
            Target.SuperGroupDsc = Source.SuperGroupCd,
            Target.SuperGroupNm = Source.SuperGroupNm,
			Target.IsActive = 1
        WHEN NOT MATCHED BY Source THEN UPDATE
        SET Target.IsActive = 0;

        --Logging End
        EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'UspLoadProfitCenterHierarchy', 'UspLoadUspLoadProfitCenterHierarchy','Load Items Data', 'END', NULL, @BatchId
        
        --Send sucess email to MPS Recon support PDL
        --EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspLoadUspLoadProfitCenterHierarchy Successful'

    END TRY
    BEGIN CATCH 
        
        --Send failure email to MPS Recon support PDL 
        SET @Prog = ERROR_PROCEDURE();
        SET @EmailMessage='UspLoadProfitCenterHierarchy failed '+' at line : '+ CONVERT(varchar(10),(ERROR_LINE()))+ '<BR>' +'Error in : '+@Prog+ '<BR>'+ 'Error Message : ' + ERROR_MESSAGE()

        EXEC dbo.UspMPSReconSendEmail @EmailBody=@EmailMessage,@EmailSubject='UspLoadProfitCenterHierarchy Failed'

        --Add Entry in Log Table
        DECLARE @ErrorMsg VARCHAR(MAX)=ERROR_MESSAGE()
        EXEC dbo.UspAddApplicationLog 'Database', 'Info', 'UspLoadProfitCenterHierarchy','UspLoadUspLoadProfitCenterHierarchy', 'Load ProfitCenterHierarchy','ERROR', @ErrorMsg, @BatchId

        RAISERROR(@ErrorMsg, 16, 1)
    END CATCH
    
    SET NOCOUNT OFF
END
