CREATE   PROCEDURE [dbo].[UspGuiEsdFetchMRPDataDisplay] 
			AS 


			select a.ESDVersionId as EsdVersionId,a.EsdVersionName, 'FabMps:'+cast(b.SourceVersionId as varchar(10))
			+' IsMps:'+cast(c.SourceVersionId as varchar(10))
			+' OneMps:'+cast(d.SourceVersionId as varchar(10))
			+' Compass:'+cast(isnull(e.SourceVersionId,'1') as varchar(10)) As Versions
			, IsNull([RestrictHorizonInd], 0) AS [RestrictHorizonInd]
			 from 
			(
				select ESDVersionId, EsdVersionName, Esd.[RestrictHorizonInd] from dbo.ESDVersions ESD
				LEFT JOIN dbo.SvdSourceVersion svd
				ON ESD.esdversionid = SourceVersionId
				AND SvdSourceApplicationId = 2
				  
			)
			a
			 join
			(	
				select b.EsdVersionId, a.[SourceApplicationName], b.SourceVersionId from [dbo].[EtlSourceApplications] a 
				join dbo.EsdSourceVersions b 
				on a.[SourceApplicationId] =
				 b.[SourceApplicationId] 
				 WHERE SourceApplicationName = 'FabMps') b
			on a.ESDVersionId = b.EsdVersionId
			 join
			(	
				select b.EsdVersionId, a.[SourceApplicationName], b.SourceVersionId from [dbo].[EtlSourceApplications] a 
				join dbo.EsdSourceVersions b 
				on a.[SourceApplicationId] =
				 b.[SourceApplicationId] 
				 WHERE SourceApplicationName = 'IsMps') c
			on a.ESDVersionId = c.EsdVersionId
			 join
			(	
				select b.EsdVersionId, a.[SourceApplicationName], b.SourceVersionId from [dbo].[EtlSourceApplications] a 
				join dbo.EsdSourceVersions b 
				on a.[SourceApplicationId] =
				 b.[SourceApplicationId] 
				 WHERE SourceApplicationName = 'OneMps') d
			on a.ESDVersionId = d.EsdVersionId
			left join
			(	
				select b.EsdVersionId, a.[SourceApplicationName], b.SourceVersionId from [dbo].[EtlSourceApplications] a 
				join dbo.EsdSourceVersions b 
				on a.[SourceApplicationId] =
				 b.[SourceApplicationId] 
				 WHERE SourceApplicationName = 'Compass') e
			on a.ESDVersionId = e.EsdVersionId


			

	--		SELECT 'EsdVersionId' as KeyCol